import SwiftUI
import UIKit

/// Square cover art that loads asynchronously.
/// Pass `size` for a fixed square, or leave it nil
/// to fill the available width.
struct ArtworkView: View {
    let source: ArtworkSource?
    var size: CGFloat?
    var cornerRadius: CGFloat = 8

    @EnvironmentObject private var library: LibraryStore
    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?
    @State private var loadedKey: String?

    private var taskID: String {
        "\(source?.key ?? "none")#\(library.artworkRevision)"
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .overlay {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ArtworkPlaceholder()
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            }
            .task(id: taskID) {
                guard let source = source else {
                    image = nil
                    return
                }

                if loadedKey != source.key {
                    image = nil
                }

                let pixels = Int(
                    (size ?? 220) * displayScale
                )

                let loaded = await ArtworkStore.shared.image(
                    for: source,
                    maxPixel: pixels
                )

                guard !Task.isCancelled else {
                    return
                }

                if loaded != nil ||
                    loadedKey != source.key {
                    withAnimation(
                        .easeOut(duration: 0.2)
                    ) {
                        image = loaded
                    }
                }

                loadedKey = source.key
            }
    }
}

// MARK: - Artwork placeholder

struct ArtworkPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.55),
                    Color(white: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.35)

            Image(systemName: "music.note")
                .font(
                    .system(
                        size: 28,
                        weight: .regular
                    )
                )
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.3)
                .padding(8)
        }
    }
}

// MARK: - Section index

/// Contacts-style A-Z scrubber.
/// Drag or tap to jump between sections.
struct SectionIndexBar: View {
    let available: [String]
    let onSelect: (String) -> Void

    @State private var current: String?

    private let rowHeight: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            ForEach(
                SortKey.alphabet,
                id: \.self
            ) { letter in
                Text(letter)
                    .font(
                        .system(
                            size: 11,
                            weight: .semibold
                        )
                    )
                    .foregroundColor(
                        available.contains(letter)
                            ? .accentColor
                            : Color.secondary.opacity(0.4)
                    )
                    .frame(
                        width: 18,
                        height: rowHeight
                    )
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    select(at: value.location.y)
                }
                .onEnded { _ in
                    current = nil
                }
        )
        .accessibilityHidden(true)
    }

    private func select(at y: CGFloat) {
        let letters = SortKey.alphabet

        let computedIndex = Int(
            (y - 6) / rowHeight
        )

        let index = min(
            max(computedIndex, 0),
            letters.count - 1
        )

        let target =
            letters[index...].first(
                where: {
                    available.contains($0)
                }
            )
            ?? letters[..<index].last(
                where: {
                    available.contains($0)
                }
            )

        guard let target = target,
              target != current else {
            return
        }

        current = target
        onSelect(target)
    }
}

// MARK: - Track row

/// One song in a list:
/// optional cover, title, subtitle and duration.
struct TrackRow: View {
    let track: Track

    var number: Int?
    var showArtwork = true
    var subtitle: String?
    var isSelected: Bool?

    @EnvironmentObject private var player: Player
    @EnvironmentObject private var favorites:
        FavoritesStore
    @EnvironmentObject private var library:
        LibraryStore

    var body: some View {
        HStack(spacing: 12) {
            if let isSelected = isSelected {
                Image(
                    systemName:
                        isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundColor(
                    isSelected
                    ? .accentColor
                    : .secondary
                )
            }

            if showArtwork {
                ArtworkView(
                    source: library.artwork(
                        for: track
                    ),
                    size: 48,
                    cornerRadius: 6
                )
            } else if let number = number {
                Text("\(number)")
                    .font(
                        .body.monospacedDigit()
                    )
                    .foregroundColor(.secondary)
                    .frame(
                        minWidth: 24,
                        alignment: .leading
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                HStack(spacing: 6) {
                    if player.current?.id == track.id {
                        Image(
                            systemName:
                                player.isPlaying
                                ? "waveform"
                                : "speaker.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }

                    Text(track.title)
                        .lineLimit(1)
                }

                if let subtitle = subtitle,
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if favorites.isFavorite(track) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            if track.isSpatial {
                Image(
                    systemName:
                        "dot.radiowaves.left.and.right"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Text(
                Formatting.duration(
                    track.duration
                )
            )
            .font(
                .subheadline.monospacedDigit()
            )
            .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Track menu

/// Play next, queue, favourite, share and delete.
/// Shared by every list of songs.
struct TrackMenuItems: View {
    let tracks: [Track]
    var album: Album?
    let onDelete: ([Track]) -> Void

    @EnvironmentObject private var player: Player
    @EnvironmentObject private var favorites:
        FavoritesStore
    @EnvironmentObject private var router:
        AppRouter

    var body: some View {
        Button {
            player.playNext(tracks)
        } label: {
            Label(
                "Play Next",
                systemImage:
                    "text.line.first.and.arrowtriangle.forward"
            )
        }

        Button {
            player.addToQueue(tracks)
        } label: {
            Label(
                "Add to Queue",
                systemImage:
                    "text.line.last.and.arrowtriangle.forward"
            )
        }

        Button {
            router.addToPlaylist(tracks)
        } label: {
            Label(
                "Add to Playlist…",
                systemImage: "text.badge.plus"
            )
        }

        if let album = album {
            ArtworkMenu(
                target: .album(album)
            )
        } else if tracks.count == 1,
                  let track = tracks.first {
            ArtworkMenu(
                target: .track(track)
            )

            Button {
                router.importLyrics(
                    for: track
                )
            } label: {
                Label(
                    "Import Lyrics (.lrc)…",
                    systemImage: "quote.bubble"
                )
            }
        }

        if let album = album {
            Button {
                favorites.toggle(album)
            } label: {
                if favorites.isFavorite(album) {
                    Label(
                        "Unfavorite Album",
                        systemImage: "star.slash"
                    )
                } else {
                    Label(
                        "Favorite Album",
                        systemImage: "star"
                    )
                }
            }
        } else if tracks.count == 1,
                  let track = tracks.first {
            Button {
                favorites.toggle(track)
            } label: {
                if favorites.isFavorite(track) {
                    Label(
                        "Unfavorite",
                        systemImage: "star.slash"
                    )
                } else {
                    Label(
                        "Favorite",
                        systemImage: "star"
                    )
                }
            }
        }

        if tracks.count == 1,
           let track = tracks.first {
            Button {
                presentShareSheet(
                    items: [track.url]
                )
            } label: {
                Label(
                    "Share File",
                    systemImage:
                        "square.and.arrow.up"
                )
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete(tracks)
        } label: {
            Label(
                tracks.count == 1
                    ? "Delete from Library"
                    : "Delete \(tracks.count) Songs",
                systemImage: "trash"
            )
        }
    }
}

// MARK: - Artwork menu

/// Change artwork submenu:
/// Photos, Files or original artwork.
struct ArtworkMenu: View {
    let target: ArtworkTarget

    @EnvironmentObject private var router:
        AppRouter
    @EnvironmentObject private var library:
        LibraryStore

    var body: some View {
        Menu {
            Button {
                router.pickArtworkPhoto(
                    for: target
                )
            } label: {
                Label(
                    "Choose from Photos…",
                    systemImage:
                        "photo.on.rectangle"
                )
            }

            Button {
                router.importArtworkFile(
                    for: target
                )
            } label: {
                Label(
                    "Choose from Files…",
                    systemImage: "folder"
                )
            }

            if library.hasCustomArtwork(target) {
                Button(role: .destructive) {
                    Task {
                        await library
                            .removeCustomArtwork(
                                for: target
                            )
                    }
                } label: {
                    Label(
                        "Use Original Artwork",
                        systemImage:
                            "arrow.uturn.backward"
                    )
                }
            }
        } label: {
            Label(
                "Change Artwork",
                systemImage: "photo"
            )
        }
    }
}

// MARK: - Delete confirmation

/// Asks before deleting files from the phone,
/// then cleans up queue and favourites.
struct DeleteConfirmation: ViewModifier {
    @Binding var pending: [Track]?

    var onDeleted: (([Track]) -> Void)?

    @EnvironmentObject private var library:
        LibraryStore
    @EnvironmentObject private var player:
        Player
    @EnvironmentObject private var favorites:
        FavoritesStore
    @EnvironmentObject private var playlists:
        PlaylistStore

    func body(
        content: Content
    ) -> some View {
        content.confirmationDialog(
            title,
            isPresented: Binding(
                get: {
                    pending != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pending = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                "Delete",
                role: .destructive
            ) {
                guard let tracks = pending else {
                    return
                }

                player.remove(tracks)
                favorites.forget(tracks)
                playlists.forget(tracks)
                library.delete(tracks)

                pending = nil
                onDeleted?(tracks)
            }
        } message: {
            Text(
                "The files are removed " +
                "from this iPhone."
            )
        }
    }

    private var title: String {
        let count = pending?.count ?? 0

        return count == 1
            ? "Delete this song?"
            : "Delete \(count) songs?"
    }
}

extension View {
    func confirmDelete(
        _ pending: Binding<[Track]?>,
        onDeleted: (([Track]) -> Void)? = nil
    ) -> some View {
        modifier(
            DeleteConfirmation(
                pending: pending,
                onDeleted: onDeleted
            )
        )
    }
}

// MARK: - Badge

/// Small rounded label used for Lossless,
/// Spatial and similar values.
struct BadgeLabel: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage = systemImage {
                Image(
                    systemName: systemImage
                )
            }

            Text(text)
        }
        .font(
            .caption2.weight(.semibold)
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .overlay(
            RoundedRectangle(
                cornerRadius: 4
            )
            .strokeBorder(
                Color.secondary.opacity(0.6),
                lineWidth: 1
            )
        )
        .foregroundColor(.secondary)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(
                    .system(size: 40)
                )
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

// MARK: - iOS 15 share helper

private func presentShareSheet(
    items: [Any]
) {
    let activityController =
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

    guard let windowScene =
        UIApplication.shared.connectedScenes
            .compactMap({
                $0 as? UIWindowScene
            })
            .first,
          let window =
              windowScene.windows.first(
                  where: {
                      $0.isKeyWindow
                  }
              ),
          let rootController =
              window.rootViewController else {
        return
    }

    var presentingController =
        rootController

    while let presentedController =
        presentingController
            .presentedViewController {
        presentingController =
            presentedController
    }

    if let popover =
        activityController
            .popoverPresentationController {
        popover.sourceView =
            presentingController.view

        popover.sourceRect = CGRect(
            x:
                presentingController
                    .view.bounds.midX,
            y:
                presentingController
                    .view.bounds.midY,
            width: 0,
            height: 0
        )

        popover.permittedArrowDirections = []
    }

    presentingController.present(
        activityController,
        animated: true
    )
}
