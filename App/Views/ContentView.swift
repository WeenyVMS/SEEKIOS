import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var soulseek: SoulseekModel
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var updates: UpdateChecker
    @AppStorage(AccentPalette.storageKey) private var accentHex = AccentPalette.defaultHex

    var body: some View {
        TabView(selection: $router.tab) {
    LibraryView()
        .tabItem {
            Label("Library", systemImage: "music.note.house")
        }
        .tag(AppTab.library)

    SearchView()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
        .tag(AppTab.search)

    DownloadsView()
        .tabItem {
            Label("Downloads", systemImage: "arrow.down.circle")
        }
        .tag(AppTab.downloads)
        .badge(soulseek.activeDownloadCount)

    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gearshape")
        }
        .tag(AppTab.settings)
}
        .modifier(TabAccessoryMiniPlayer(isVisible: player.current != nil, open: openPlayer))
        .modifier(RouterPresenters(active: !router.showPlayer))
        .sheet(isPresented: $router.showPlayer) {
            NowPlayingView()
                .modifier(RouterPresenters(active: true))
                .tint(Color(hex: accentHex))
        }
        .onChange(of: library.artworkRevision) { _ in
    player.reloadArtwork()
}
        .onChange(of: accentHex) { newHex in
            syncAppIcon(with: newHex)
        }
        .tint(Color(hex: accentHex))
    }

    private func openPlayer() {
        router.showPlayer = true
    }

    private func syncAppIcon(with hex: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        let iconName = "AppIcon_\(cleanHex)"
        if UIApplication.shared.alternateIconName != iconName {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if error != nil {
                    // Si el color es el predeterminado o no existe variante, vuelve al icono principal
                    UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
                }
            }
        }
    }
}

/// Banner shown on screens that need the Soulseek connection.
struct ConnectionBanner: View {
    @EnvironmentObject private var soulseek: SoulseekModel

    var body: some View {
        switch soulseek.connection {
        case .loggedIn:
            EmptyView()
        case .connecting:
            Label("Connecting…", systemImage: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .disconnected:
            Label(soulseek.hasCredentials ? "Disconnected" : "Log in under Settings to search Soulseek",
                  systemImage: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.secondary)
        }
    }
}
