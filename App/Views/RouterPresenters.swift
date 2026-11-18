import PhotosUI
import SwiftUI
import UIKit

/// Pickers and sheets requested by AppRouter.
///
/// This modifier can be attached both to the main tab view and
/// to the Now Playing sheet. The `active` property ensures that
/// only the frontmost modifier presents a picker or sheet.
struct RouterPresenters: ViewModifier {
    let active: Bool

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var playlists: PlaylistStore

    func body(content: Content) -> some View {
        content
            .sheet(
                item:
                    active
                    ? $router.playlistRequest
                    : .constant(nil)
            ) { request in
                AddToPlaylistSheet(
                    request: request
                )
            }
            .fileImporter(
                isPresented:
                    active
                    ? $router.showImporter
                    : .constant(false),
                allowedContentTypes:
                    router.importKind.types,
                allowsMultipleSelection:
                    router.importKind
                        .allowsMultiple
            ) { result in
                guard case let .success(urls) =
                    result,
                    !urls.isEmpty else {
                    return
                }

                handleImport(
                    urls,
                    kind: router.importKind
                )
            }
            .sheet(
                isPresented:
                    active
                    ? $router.showPhotoPicker
                    : .constant(false)
            ) {
                LegacyPhotoPicker(
                    onPick: { data in
                        router.showPhotoPicker = false

                        guard let target =
                            router.photoTarget else {
                            return
                        }

                        Task {
                            let success =
                                await library
                                    .setCustomArtwork(
                                        data,
                                        for: target
                                    )

                            if !success {
                                router.message =
                                    "That image couldn't be used."
                            }
                        }
                    },
                    onCancel: {
                        router.showPhotoPicker = false
                    }
                )
                .ignoresSafeArea()
            }
            .alert(
                router.message ?? "",
                isPresented: Binding(
                    get: {
                        active &&
                        router.message != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            router.message = nil
                        }
                    }
                )
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {
                }
            }
    }

    // MARK: - File import

    private func handleImport(
        _ urls: [URL],
        kind: ImportKind
    ) {
        switch kind {
        case .music:
            importMusic(urls)

        case .playlist:
            importPlaylist(urls)

        case let .lyrics(track):
            importLyrics(
                urls,
                for: track
            )

        case let .artwork(target):
            importArtwork(
                urls,
                for: target
            )
        }
    }

    private func importMusic(
        _ urls: [URL]
    ) {
        let lyricsOnly =
            urls.allSatisfy {
                $0.pathExtension
                    .lowercased() == "lrc"
            }

        Task {
            let count =
                await library.importItems(urls)

            if lyricsOnly {
                router.lyricsChanged()

                router.message =
                    "Lyrics files were matched " +
                    "to songs with the same file name."
            } else {
                router.message =
                    count == 0
                    ? "No audio files found."
                    : "Imported \(count) song" +
                        "\(count == 1 ? "" : "s")."
            }
        }
    }

    private func importPlaylist(
        _ urls: [URL]
    ) {
        guard let firstURL = urls.first else {
            return
        }

        if let playlist =
            playlists.importM3U(
                firstURL,
                library: library
            ) {
            router.message =
                "Imported “\(playlist.name)” with " +
                "\(playlist.trackIDs.count) songs."
        } else {
            router.message =
                "None of the playlist's songs " +
                "are in your library."
        }
    }

    private func importLyrics(
        _ urls: [URL],
        for track: Track
    ) {
        guard let firstURL = urls.first else {
            return
        }

        if library.importLyrics(
            from: firstURL,
            for: track
        ) {
            Task {
                await LyricsService.shared.forget(
                    cacheKey: track.id
                )
            }

            router.lyricsChanged()
        } else {
            router.message =
                "Couldn't read that lyrics file."
        }
    }

    private func importArtwork(
        _ urls: [URL],
        for target: ArtworkTarget
    ) {
        guard let url = urls.first else {
            return
        }

        Task {
            let scoped =
                url.startAccessingSecurityScopedResource()

            let data =
                try? Data(contentsOf: url)

            if scoped {
                url.stopAccessingSecurityScopedResource()
            }

            guard let data = data else {
                router.message =
                    "That image couldn't be read."
                return
            }

            let success =
                await library.setCustomArtwork(
                    data,
                    for: target
                )

            if !success {
                router.message =
                    "That image couldn't be used."
            }
        }
    }
}

// MARK: - iOS 15 photo picker

/// UIKit photo picker compatible with iOS 14 and later.
///
/// This replaces SwiftUI's PhotosPicker and PhotosPickerItem,
/// which require iOS 16.
struct LegacyPhotoPicker:
    UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(
        context: Context
    ) -> PHPickerViewController {
        var configuration =
            PHPickerConfiguration(
                photoLibrary: .shared()
            )

        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode =
            .current

        let picker =
            PHPickerViewController(
                configuration: configuration
            )

        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController:
            PHPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator:
        NSObject,
        PHPickerViewControllerDelegate {
        private let parent: LegacyPhotoPicker

        init(parent: LegacyPhotoPicker) {
            self.parent = parent
        }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results:
                [PHPickerResult]
        ) {
            guard let result = results.first else {
                picker.dismiss(animated: true)
                parent.onCancel()
                return
            }

            let provider = result.itemProvider

            guard provider.canLoadObject(
                ofClass: UIImage.self
            ) else {
                picker.dismiss(animated: true)
                parent.onCancel()
                return
            }

            provider.loadObject(
                ofClass: UIImage.self
            ) {
                [weak self, weak picker]
                object,
                error in

                guard let self = self else {
                    return
                }

                guard error == nil,
                      let image =
                          object as? UIImage else {
                    DispatchQueue.main.async {
                        picker?.dismiss(
                            animated: true
                        )
                        self.parent.onCancel()
                    }
                    return
                }

                let data =
                    image.jpegData(
                        compressionQuality: 0.95
                    )
                    ?? image.pngData()

                DispatchQueue.main.async {
                    picker?.dismiss(
                        animated: true
                    )

                    if let data = data {
                        self.parent.onPick(data)
                    } else {
                        self.parent.onCancel()
                    }
                }
            }
        }
    }
}
