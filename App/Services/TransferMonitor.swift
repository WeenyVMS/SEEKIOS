import Combine
import Foundation
import SoulseekKit
import UserNotifications

/// Maintains transfers in the background,
/// sends completion notifications and manages automatic retries.
///
/// Live Activities and Dynamic Island are intentionally disabled
/// because ActivityKit is not available on iOS 15.
@MainActor
final class TransferMonitor {
    private let soulseek: SoulseekModel
    private let player: Player
    private weak var stats: StatsStore?

    private let keeper = BackgroundKeeper()

    private var subscriptions =
        Set<AnyCancellable>()

    private var heartbeat: Timer?
    private var lastReconnect =
        Date.distantPast

    private var notifiedCompletedIDs =
        Set<DownloadID>()

    private var initializedCompleted = false

    /// Automatic retry counters.
    private var retryCounts:
        [DownloadID: Int] = [:]

    /// Tasks waiting before retrying failed downloads.
    private var pendingRetryTimers:
        [DownloadID: Task<Void, Never>] = [:]

    init(
        soulseek: SoulseekModel,
        player: Player,
        stats: StatsStore
    ) {
        self.soulseek = soulseek
        self.player = player
        self.stats = stats

        requestNotificationPermission()

        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(
                withIdentifiers: [
                    "seekios.transfer.progress"
                ]
            )

        for item in soulseek.downloads {
            if case .completed = item.state {
                notifiedCompletedIDs.insert(
                    item.id
                )
            }
        }

        initializedCompleted = true

        soulseek.$downloads
            .combineLatest(
                soulseek.$uploads,
                player.$isPlaying
            )
            .throttle(
                for: .seconds(1.0),
                scheduler: DispatchQueue.main,
                latest: true
            )
            .sink {
                [weak self] _,
                _,
                _ in

                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
            .store(
                in: &subscriptions
            )

        NotificationCenter.default
            .publisher(
                for:
                    UserDefaults
                        .didChangeNotification
            )
            .debounce(
                for: .milliseconds(300),
                scheduler: DispatchQueue.main
            )
            .sink {
                [weak self] _ in

                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
            .store(
                in: &subscriptions
            )

        heartbeat =
            Timer.scheduledTimer(
                withTimeInterval: 20,
                repeats: true
            ) {
                [weak self] _ in

                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
    }

    deinit {
        heartbeat?.invalidate()

        for task in pendingRetryTimers.values {
            task.cancel()
        }
    }

    var isSeeding: Bool {
        AppSettings.seedingEnabled
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [
                    .alert,
                    .sound,
                    .badge
                ]
            ) {
                _,
                _ in
            }
    }

    // MARK: - Transfer monitoring

    func refresh() {
        update(
            downloads: soulseek.downloads,
            uploads: soulseek.uploads,
            isPlaying: player.isPlaying
        )
    }

    private func update(
        downloads: [DownloadItem],
        uploads: [UploadItem],
        isPlaying: Bool
    ) {
        let visibleDownloads =
            downloads.filter {
                !$0.isArtwork
            }

        let activeDownloads =
            visibleDownloads.filter {
                $0.isActive
            }

        let activeUploads =
            uploads.filter {
                $0.state == .transferring
            }

        let hasActiveTransfers =
            !activeDownloads.isEmpty ||
            !activeUploads.isEmpty

        let seeding =
            isSeeding &&
            soulseek.hasCredentials

        reconnectForSeedingIfNeeded(
            seeding: seeding
        )

        updateBackgroundKeeper(
            hasActiveTransfers:
                hasActiveTransfers,
            seeding: seeding,
            isPlaying: isPlaying
        )

        notifyNewlyCompletedDownloads(
            downloads
        )

        handleAutoRetry(
            downloads
        )
    }

    private func reconnectForSeedingIfNeeded(
        seeding: Bool
    ) {
        guard seeding else {
            return
        }

        guard !soulseek.isLoggedIn else {
            return
        }

        guard Date()
            .timeIntervalSince(
                lastReconnect
            ) > 60 else {
            return
        }

        lastReconnect = Date()

        soulseek.reconnectIfNeeded()
    }

    private func updateBackgroundKeeper(
        hasActiveTransfers: Bool,
        seeding: Bool,
        isPlaying: Bool
    ) {
        let backgroundTransfersEnabled =
            AppSettings.flag(
                AppSettings
                    .backgroundTransfersKey
            )

        let wantsKeeper =
            (
                hasActiveTransfers &&
                backgroundTransfersEnabled
            )
            || seeding

        if wantsKeeper && !isPlaying {
            keeper.start()
        } else {
            keeper.stop()
        }
    }

    // MARK: - Automatic retry

    private func handleAutoRetry(
        _ downloads: [DownloadItem]
    ) {
        let currentIDs =
            Set(
                downloads
                    .filter {
                        !$0.isArtwork
                    }
                    .map(\.id)
            )

        removeRetryStateForMissingDownloads(
            currentIDs: currentIDs
        )

        for item in downloads
        where !item.isArtwork {
            let itemID = item.id

            switch item.state {
            case .failed:
                scheduleRetryIfNeeded(
                    for: item
                )

            case .completed:
                clearRetryState(
                    for: itemID
                )

            default:
                break
            }
        }
    }

    private func scheduleRetryIfNeeded(
        for item: DownloadItem
    ) {
        let itemID = item.id

        let attempts =
            retryCounts[
                itemID,
                default: 0
            ]

        guard attempts < 3 else {
            return
        }

        guard pendingRetryTimers[itemID]
            == nil else {
            return
        }

        pendingRetryTimers[itemID] =
            Task {
                [weak self] in

                try? await Task.sleep(
                    nanoseconds:
                        120_000_000_000
                )

                guard !Task.isCancelled else {
                    return
                }

                guard let self = self else {
                    return
                }

                self.retryCounts[itemID] =
                    attempts + 1

                self.pendingRetryTimers
                    .removeValue(
                        forKey: itemID
                    )

                self.soulseek.retry(item)
            }
    }

    private func clearRetryState(
        for itemID: DownloadID
    ) {
        retryCounts.removeValue(
            forKey: itemID
        )

        pendingRetryTimers[itemID]?
            .cancel()

        pendingRetryTimers.removeValue(
            forKey: itemID
        )
    }

    private func removeRetryStateForMissingDownloads(
        currentIDs: Set<DownloadID>
    ) {
        let obsoleteIDs =
            Set(
                retryCounts.keys
            )
            .union(
                pendingRetryTimers.keys
            )
            .subtracting(currentIDs)

        for itemID in obsoleteIDs {
            clearRetryState(
                for: itemID
            )
        }
    }

    // MARK: - Completion notification

    private func notifyNewlyCompletedDownloads(
        _ downloads: [DownloadItem]
    ) {
        guard initializedCompleted else {
            return
        }

        var newlyFinished:
            [DownloadItem] = []

        for item in downloads
        where !item.isArtwork {
            if case .completed = item.state {
                if !notifiedCompletedIDs
                    .contains(item.id) {
                    notifiedCompletedIDs
                        .insert(item.id)

                    newlyFinished.append(item)
                }
            } else {
                notifiedCompletedIDs
                    .remove(item.id)
            }
        }

        guard !newlyFinished.isEmpty else {
            return
        }

        let content =
            UNMutableNotificationContent()

        if newlyFinished.count == 1,
           let first =
               newlyFinished.first {
            content.title =
                "Download Complete"

            content.body =
                "\(first.filename) " +
                "(\(Formatting.bytes(first.size)))"
        } else if let first =
            newlyFinished.first {
            content.title =
                "\(newlyFinished.count) " +
                "Downloads Complete"

            content.body =
                "\(first.filename) and " +
                "\(newlyFinished.count - 1) " +
                "more finished."
        }

        content.sound = .default

        let request =
            UNNotificationRequest(
                identifier:
                    "seekios.done." +
                    UUID().uuidString,
                content: content,
                trigger: nil
            )

        UNUserNotificationCenter.current()
            .add(request)
    }
}
