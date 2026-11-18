import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var soulseek: SoulseekModel
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var server: WiFiTransferServer

    @AppStorage(
        AppSettings.artworkLookupKey
    )
    private var artworkLookup = true

    @AppStorage(
        AppSettings.lyricsLookupKey
    )
    private var lyricsLookup = true

    @AppStorage(
        AppSettings.backgroundTransfersKey
    )
    private var backgroundTransfers = true

    @AppStorage(
        AppSettings.transferActivityKey
    )
    private var transferActivity = true

    @AppStorage(
        AppSettings.showMissingKey
    )
    private var showMissing = true

    @AppStorage(
        AppSettings.musicBrainzKey
    )
    private var musicBrainz = true

    @AppStorage(
        AppSettings.seedingKey
    )
    private var seeding = false

    @State private var username = ""
    @State private var password = ""
    @State private var showFolderPicker = false
    @State private var showDownloadsFolderSheet = false

    private var appVersionText: String {
        let shortVersion =
            Bundle.main.infoDictionary?[
                "CFBundleShortVersionString"
            ] as? String ?? "1.0"

        let buildNumber =
            Bundle.main.infoDictionary?[
                "CFBundleVersion"
            ] as? String ?? ""

        if !buildNumber.isEmpty &&
            !shortVersion.hasSuffix(
                ".\(buildNumber)"
            ) {
            return
                "v\(shortVersion) (\(buildNumber))"
        }

        return "v\(shortVersion)"
    }

    var body: some View {
        NavigationView {
            Form {
                wiFiTransferNavigationLink

                versionSection

                Section {
                    NavigationLink(
                        destination: StatsView()
                    ) {
                        StatsPreview()
                    }
                }

                soulseekSection

                Section("Accent Colour") {
                    AccentPicker()
                }

                playbackSection
                onlineSection
                downloadLocationSection
                transfersSection
                librarySection
                diagnosticsSection
            }
            .navigationTitle("Settings")
            .sheet(
                isPresented: $showFolderPicker
            ) {
                FolderDocumentPicker(
                    isPresented: $showFolderPicker
                ) { pickedURL in
                    soulseek.setCustomDownloadFolder(
                        pickedURL
                    )
                }
            }
            .sheet(
                isPresented:
                    $showDownloadsFolderSheet
            ) {
                NavigationView {
                    LocalFolderBrowserView(
                        folderURL:
                            soulseek
                                .otherDownloadsDirectory
                    )
                }
            }
            .onAppear {
                username = soulseek.username
            }
        }
    }

    // MARK: - Hidden navigation

    private var wiFiTransferNavigationLink:
        some View {
        NavigationLink(
            destination: WiFiTransferView(),
            isActive: $router.showWiFiTransfer
        ) {
            EmptyView()
        }
        .frame(width: 0, height: 0)
        .hidden()
    }

    // MARK: - Version

    private var versionSection: some View {
        Section("Version") {
            HStack {
                Label(
                    "Seekios",
                    systemImage: "info.circle"
                )

                Spacer()

                Text(appVersionText)
                    .foregroundColor(.secondary)
            }

            Link(
                destination: URL(
                    string:
                        "https://github.com/SRJW/SEEKIOS/releases"
                )!
            ) {
                HStack {
                    Label(
                        "View Releases on GitHub",
                        systemImage: "globe"
                    )

                    Spacer()

                    Image(
                        systemName:
                            "arrow.up.right"
                    )
                    .font(
                        .footnote.weight(.semibold)
                    )
                    .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        Section {
            NavigationLink(
                destination:
                    EqualizerView(
                        equalizer:
                            player.equalizer
                    )
            ) {
                SettingsLabeledRow(
                    "Equalizer",
                    value:
                        equalizerStatusText
                )
            }

            Toggle(
                "Bit-Perfect Mode",
                isOn: $player.bitPerfect
            )

            if player.bitPerfect {
                BitPerfectStatus()
            }
        } header: {
            Text("Playback")
        } footer: {
            Text(
                "For USB DACs: switches the output " +
                "to each song's sample rate and skips " +
                "the EQ and all volume processing, so " +
                "the DAC gets the file's exact samples. " +
                "Turn the iPhone volume all the way up " +
                "and use the DAC's volume. Bluetooth, " +
                "AirPlay and the speaker can't be " +
                "bit-perfect."
            )
        }
    }

    private var equalizerStatusText: String {
        if player.bitPerfect {
            return "Bypassed"
        }

        if player.equalizer.isEnabled {
            return player.equalizer.displayName
        }

        return "Off"
    }

    // MARK: - Online

    private var onlineSection: some View {
        Section {
            Toggle(
                "Look Up Missing Artwork",
                isOn: $artworkLookup
            )

            Toggle(
                "Fetch Lyrics",
                isOn: $lyricsLookup
            )

            Toggle(
                "Show Missing Album Songs",
                isOn: $showMissing
            )

            Toggle(
                "Look Up Tracklists on MusicBrainz",
                isOn: $musicBrainz
            )
            .disabled(!showMissing)
        } header: {
            Text("Online")
        } footer: {
            Text(
                "Artwork comes from the iTunes Search " +
                "API when a song has none of its own; " +
                "lyrics come from LRCLIB. Missing songs " +
                "come from the Soulseek folder an album " +
                "was downloaded from, or from " +
                "MusicBrainz otherwise."
            )
        }
    }

    // MARK: - Download location

    private var downloadLocationSection:
        some View {
        Section {
            HStack {
                Label(
                    "Download Folder",
                    systemImage: "folder.fill"
                )

                Spacer()

                Text(
                    soulseek
                        .currentDownloadFolderDisplayName
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Button {
                showFolderPicker = true
            } label: {
                Label(
                    "Choose Where to Save Downloads…",
                    systemImage:
                        "folder.badge.gearshape"
                )
            }

            Button {
                showDownloadsFolderSheet = true
            } label: {
                Label(
                    "Show Downloads Folder",
                    systemImage:
                        "folder.badge.magnifyingglass"
                )
            }

            if soulseek.customDownloadDirectory
                != nil {
                Toggle(
                    "Also Save Music to Chosen Folder",
                    isOn:
                        $soulseek
                            .saveAllToCustomFolder
                )

                Button(
                    "Reset Download Folder to Default",
                    role: .destructive
                ) {
                    soulseek
                        .resetDownloadFolderToDefault()
                }
            }
        } header: {
            Text("Download Location")
        } footer: {
            Text(
                "Choose any folder in On My iPhone " +
                "or iCloud Drive to automatically " +
                "store downloaded files."
            )
        }
    }

    // MARK: - Transfers

    private var transfersSection: some View {
        Section {
            Toggle(
                "Keep Transfers Running in Background",
                isOn: $backgroundTransfers
            )

            if #available(iOS 16.1, *) {
                Toggle(
                    "Show Transfers in Dynamic Island",
                    isOn: $transferActivity
                )
            } else {
                HStack {
                    Label(
                        "Dynamic Island Activities",
                        systemImage:
                            "rectangle.inset.filled"
                    )

                    Spacer()

                    Text("Requires iOS 16.1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Toggle(
                "Seeding Mode",
                isOn: $seeding
            )

            Button {
                router.showWiFiTransfer = true
            } label: {
                HStack {
                    Label(
                        "Wi-Fi Transfer",
                        systemImage: "wifi"
                    )

                    Spacer()

                    if server.isRunning {
                        Text("On")
                            .foregroundColor(.secondary)
                    }

                    Image(
                        systemName: "chevron.right"
                    )
                    .font(
                        .footnote.weight(.semibold)
                    )
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        } header: {
            Text("Transfers")
        } footer: {
            Text(
                "When nothing is playing, Seekios " +
                "plays silence mixed under other audio " +
                "so iOS doesn't freeze transfers in " +
                "the background. It costs some battery " +
                "and stops when transfers finish. " +
                "Seeding Mode keeps the connection " +
                "running so peers can continue " +
                "downloading from you."
            )
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        Section {
            SettingsLabeledRow(
                "Songs",
                value: "\(library.tracks.count)"
            )

            SettingsLabeledRow(
                "Albums",
                value: "\(library.albums.count)"
            )

            Button("Rescan Library") {
                library.rescan()
            }

            Button("Clear Artwork Cache") {
                Task {
                    await ArtworkStore.shared
                        .clearDisk()

                    library.bumpArtwork()
                }
            }
        } header: {
            Text("Library")
        } footer: {
            Text(
                "Your music is also shared back on " +
                "Soulseek while the app runs, so peers " +
                "don't treat you as a leecher."
            )
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section {
            NavigationLink(
                destination: DiagnosticsView()
            ) {
                Text("Diagnostics & Logs")
            }

            NavigationLink(
                destination: LogView()
            ) {
                Text("Connection Log")
            }
        }
    }

    // MARK: - Soulseek login

    private var soulseekSection: some View {
        Section {
            if soulseek.isLoggedIn {
                Label(
                    "Logged in as \(soulseek.username)",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .foregroundColor(.green)
            } else {
                ConnectionBanner()
            }

            TextField(
                "Username",
                text: $username
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            SecureField(
                "Password",
                text: $password
            )

            Button(
                soulseek.isLoggedIn
                    ? "Reconnect"
                    : "Log In"
            ) {
                soulseek.logIn(
                    username: username,
                    password: password
                )

                password = ""
            }
            .disabled(
                username
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                    .isEmpty
                || password.isEmpty
            )

            if soulseek.isLoggedIn {
                Button(
                    "Disconnect",
                    role: .destructive
                ) {
                    soulseek.logOut()
                }
            }
        } header: {
            Text("Soulseek")
        } footer: {
            Text(
                "Logging in with an unused username " +
                "registers it. There's no password " +
                "reset, so pick something you'll " +
                "remember."
            )
        }
    }
}

// MARK: - iOS 15 labeled row

struct SettingsLabeledRow: View {
    let title: String
    let value: String

    init(
        _ title: String,
        value: String
    ) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 12
        ) {
            Text(title)

            Spacer(minLength: 8)

            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Bit-perfect status

struct BitPerfectStatus: View {
    @EnvironmentObject private var player: Player

    var body: some View {
        let output = player.output

        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            SettingsLabeledRow(
                "Output",
                value:
                    output.routeName.isEmpty
                    ? "–"
                    : output.routeName
            )

            SettingsLabeledRow(
                "Hardware Rate",
                value:
                    Formatting.sampleRate(
                        output.hardwareRate
                    )
            )

            if output.fileRate > 0 {
                SettingsLabeledRow(
                    "Song Rate",
                    value:
                        Formatting.sampleRate(
                            output.fileRate
                        )
                )
            }

            if player.current != nil {
                if output.isBitPerfect(
                    enabled: true
                ) {
                    Label(
                        "Bit-perfect",
                        systemImage:
                            "checkmark.seal.fill"
                    )
                    .foregroundColor(.green)
                } else if let reason =
                    output.blocker(enabled: true) {
                    Label(
                        reason,
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .foregroundColor(.orange)
                }
            }
        }
        .font(.subheadline)
        .onAppear {
            player.refreshOutputInfo()
        }
    }
}

// MARK: - Connection log

struct LogView: View {
    @EnvironmentObject private var soulseek:
        SoulseekModel

    var body: some View {
        List(
            Array(
                soulseek.logLines.indices.reversed()
            ),
            id: \.self
        ) { index in
            Text(soulseek.logLines[index])
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}
