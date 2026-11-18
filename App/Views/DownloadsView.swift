import QuickLook
import SoulseekKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LocalFolderItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

// MARK: - Downloads

struct DownloadsView: View {
    @EnvironmentObject private var soulseek: SoulseekModel
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: Player
    @EnvironmentObject private var router: AppRouter

    @State private var selection = Set<DownloadID>()
    @State private var editMode: EditMode = .inactive
    @State private var previewURL: URL?
    @State private var folderToBrowse: LocalFolderItem?
    @State private var showFolderPicker = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""

    private var activeDownloads: [DownloadItem] {
        soulseek.visibleDownloads.filter(\.isActive)
    }

    private var failedDownloads: [DownloadItem] {
        soulseek.visibleDownloads.filter {
            if case .failed = $0.state {
                return true
            }

            return false
        }
    }

    private var completedDownloads: [DownloadItem] {
        soulseek.visibleDownloads.filter {
            if case .completed = $0.state {
                return true
            }

            return false
        }
    }

    private var groupedByFolder: [
        (
            folderName: String,
            username: String,
            items: [DownloadItem]
        )
    ] {
        var groups: [
            String: (
                folderName: String,
                username: String,
                items: [DownloadItem]
            )
        ] = [:]

        var order: [String] = []

        for item in soulseek.visibleDownloads {
            let folder =
                item.folderPath
                    .split(separator: "\\")
                    .last
                    .map(String.init)
                ?? item.id.username

            let key = "\(item.id.username)|\(folder)"

            if groups[key] == nil {
                order.append(key)

                groups[key] = (
                    folderName: folder,
                    username: item.id.username,
                    items: []
                )
            }

            groups[key]?.items.append(item)
        }

        return order.compactMap {
            groups[$0]
        }
    }

    private func localContainerFolder(
        for group: (
            folderName: String,
            username: String,
            items: [DownloadItem]
        )
    ) -> URL {
        for item in group.items {
            if case let .completed(url) = item.state {
                let parent = url.deletingLastPathComponent()

                if FileManager.default.fileExists(
                    atPath: parent.path
                ) {
                    return parent
                }
            }
        }

        let candidate =
            soulseek.otherDownloadsDirectory
                .appendingPathComponent(
                    group.folderName,
                    isDirectory: true
                )

        if FileManager.default.fileExists(
            atPath: candidate.path
        ) {
            return candidate
        }

        return soulseek.otherDownloadsDirectory
    }

    var body: some View {
        NavigationView {
            List(selection: $selection) {
                downloadDestinationSection

                if !soulseek.visibleDownloads.isEmpty {
                    globalActionsSection
                }

                if !soulseek.uploads.isEmpty {
                    uploadsSection
                }

                downloadsSections
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Downloads")
            .environment(\.editMode, $editMode)
            .toolbar {
                topToolbar

                if editMode == .active &&
                    !selection.isEmpty {
                    selectionToolbar
                }
            }
            .sheet(item: $folderToBrowse) { item in
                NavigationView {
                    LocalFolderBrowserView(
                        folderURL: item.url
                    )
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderDocumentPicker(
                    isPresented: $showFolderPicker
                ) { pickedURL in
                    soulseek.setCustomDownloadFolder(
                        pickedURL
                    )
                }
                .ignoresSafeArea()
            }
            .alert(
                "Create New Download Folder",
                isPresented: $showNewFolderAlert
            ) {
                TextField(
                    "Folder name (e.g. Peliculas, Musica)",
                    text: $newFolderName
                )

                Button("Create & Select") {
                    soulseek.createAndSelectSubfolder(
                        named: newFolderName
                    )
                }

                Button(
                    "Cancel",
                    role: .cancel
                ) {
                }
            } message: {
                Text(
                    "Creates a folder inside " +
                    "On My iPhone › Seekios and sets it " +
                    "as your active download folder."
                )
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: {
                        previewURL != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            previewURL = nil
                        }
                    }
                )
            ) {
                if let previewURL = previewURL {
                    QuickLookPreview(url: previewURL)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if soulseek.visibleDownloads.isEmpty &&
                    soulseek.uploads.isEmpty {
                    EmptyStateView(
    title: "No Transfers",
    systemImage: "arrow.down.circle",
    message:
        "Files you download from Search appear here. " +
        "Interrupted downloads are saved on disk and " +
        "resume automatically."
)
                }
            }
        }
    }

    // MARK: Download destination

    private var downloadDestinationSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(
                    systemName:
                        "folder.fill.badge.gearshape"
                )
                .font(.title3)
                .foregroundColor(.accentColor)

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text("Save Location")
                        .font(
                            .subheadline.weight(.semibold)
                        )

                    Text(
                        soulseek
                            .currentDownloadFolderDisplayName
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Button("Choose Folder") {
                    showFolderPicker = true
                }
                .buttonStyle(
                    BorderedProminentButtonStyle()
                )
                .controlSize(.small)
            }

            HStack(spacing: 16) {
                Button {
                    folderToBrowse = LocalFolderItem(
                        url:
                            soulseek
                                .otherDownloadsDirectory
                    )
                } label: {
                    Label(
                        "Show Downloads Folder",
                        systemImage: "folder.fill"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label(
                        "New Folder…",
                        systemImage: "folder.badge.plus"
                    )
                    .font(
                        .caption.weight(.semibold)
                    )
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }

            if soulseek.customDownloadDirectory != nil {
                Toggle(
                    "Also Copy Music to Chosen Folder",
                    isOn:
                        $soulseek.saveAllToCustomFolder
                )

                Button(
                    "Reset to Default App Folder",
                    role: .destructive
                ) {
                    soulseek.resetDownloadFolderToDefault()
                }
                .font(.footnote)
            }
        } header: {
            Text("Download Destination")
        } footer: {
            Text(
                "Tip: In the iOS folder picker, open " +
                "any subfolder, or tap the New Folder " +
                "icon at the top-right, then tap Open."
            )
        }
    }

    // MARK: Global actions

    private var globalActionsSection: some View {
        Section {
            HStack(spacing: 12) {
                if !failedDownloads.isEmpty {
                    Button {
                        soulseek.retryAllFailed()
                    } label: {
                        Label(
                            "Resume All " +
                            "(\(failedDownloads.count))",
                            systemImage:
                                "arrow.clockwise.circle.fill"
                        )
                        .font(
                            .caption.weight(.semibold)
                        )
                    }
                    .buttonStyle(
                        BorderedProminentButtonStyle()
                    )
                    .tint(.orange)
                }

                if !completedDownloads.isEmpty {
                    Button {
                        soulseek.clearCompleted()
                    } label: {
                        Label(
                            "Clear Done",
                            systemImage:
                                "checkmark.circle"
                        )
                        .font(
                            .caption.weight(.semibold)
                        )
                    }
                    .buttonStyle(
                        BorderedButtonStyle()
                    )
                }

                Spacer()

                Text(
                    "\(activeDownloads.count) active · " +
                    "\(completedDownloads.count) done"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Uploads

    private var uploadsSection: some View {
        Section(
            "Uploads (\(soulseek.uploads.count))"
        ) {
            ForEach(soulseek.uploads) { upload in
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: 3
                    ) {
                        Text(upload.filename)
                            .lineLimit(1)

                        Text(
                            "To \(upload.id.username) · " +
                            "\(Formatting.bytes(upload.sent)) / " +
                            "\(Formatting.bytes(upload.size))"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)

                        ProgressView(value: upload.progress)
                    }
                }
            }
        }
    }

    // MARK: Download folders

    private var downloadsSections: some View {
        ForEach(
            groupedByFolder,
            id: \.folderName
        ) { group in
            Section {
                ForEach(group.items) { item in
                    DownloadRow(
                        item: item,
                        onPreview: { url in
                            previewURL = url
                        },
                        onShowFolder: { folderURL in
                            folderToBrowse =
                                LocalFolderItem(
                                    url: folderURL
                                )
                        }
                    )
                    .tag(item.id)
                }
            } header: {
                HStack {
                    Label(
                        group.folderName,
                        systemImage: "folder.fill"
                    )
                    .font(
                        .subheadline.weight(.semibold)
                    )
                    .lineLimit(1)

                    Spacer()

                    Button {
                        let targetFolder =
                            localContainerFolder(
                                for: group
                            )

                        folderToBrowse =
                            LocalFolderItem(
                                url: targetFolder
                            )
                    } label: {
                        Label(
                            "Show Folder",
                            systemImage:
                                "folder.badge.magnifyingglass"
                        )
                        .font(
                            .caption.weight(.semibold)
                        )
                    }
                    .textCase(nil)
                }
            } footer: {
                HStack {
                    Text("From \(group.username)")

                    Spacer()

                    if group.items.contains(
                        where: { item in
                            if case .failed = item.state {
                                return true
                            }

                            return false
                        }
                    ) {
                        Button("Resume Folder") {
                            soulseek.retryFailed(
                                from: group.username
                            )
                        }
                        .font(
                            .caption2.weight(.semibold)
                        )
                    }
                }
            }
        }
    }

    // MARK: Toolbars

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItemGroup(
            placement: .navigationBarTrailing
        ) {
            if !soulseek.visibleDownloads.isEmpty {
                Button(
                    editMode == .active
                        ? "Done"
                        : "Select"
                ) {
                    withAnimation {
                        editMode =
                            editMode == .active
                            ? .inactive
                            : .active

                        if editMode == .inactive {
                            selection.removeAll()
                        }
                    }
                }
            }

            Menu {
                Button {
                    folderToBrowse = LocalFolderItem(
                        url:
                            soulseek
                                .otherDownloadsDirectory
                    )
                } label: {
                    Label(
                        "Show Downloads Folder",
                        systemImage: "folder"
                    )
                }

                Button {
                    showFolderPicker = true
                } label: {
                    Label(
                        "Change Download Location…",
                        systemImage:
                            "folder.badge.gearshape"
                    )
                }

                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Label(
                        "Create New Download Folder…",
                        systemImage:
                            "folder.badge.plus"
                    )
                }

                Divider()

                if !failedDownloads.isEmpty {
                    Button {
                        soulseek.retryAllFailed()
                    } label: {
                        Label(
                            "Resume / Retry All Interrupted",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }

                if !completedDownloads.isEmpty {
                    Button {
                        soulseek.clearCompleted()
                    } label: {
                        Label(
                            "Clear Completed",
                            systemImage:
                                "checkmark.circle"
                        )
                    }
                }

                if !failedDownloads.isEmpty {
                    Button(role: .destructive) {
                        soulseek.clearFailed()
                    } label: {
                        Label(
                            "Remove Failed",
                            systemImage: "xmark.circle"
                        )
                    }
                }

                if !activeDownloads.isEmpty {
                    Button(role: .destructive) {
                        soulseek.cancelAllActive()
                    } label: {
                        Label(
                            "Cancel All Active",
                            systemImage: "stop.circle"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(
                "Resume (\(selection.count))"
            ) {
                soulseek.retry(selection)
                selection.removeAll()
                editMode = .inactive
            }

            Spacer()

            Button(
                "Delete (\(selection.count))",
                role: .destructive
            ) {
                soulseek.remove(
                    selection,
                    deletePartial: true
                )
                selection.removeAll()
                editMode = .inactive
            }
        }
    }
}

// MARK: - Download row

struct DownloadRow: View {
    let item: DownloadItem
    let onPreview: (URL) -> Void
    let onShowFolder: (URL) -> Void

    @EnvironmentObject private var soulseek:
        SoulseekModel
    @EnvironmentObject private var library:
        LibraryStore
    @EnvironmentObject private var player:
        Player

    @State private var shareURL: URL?

    private var fileExtension: String {
        (item.filename as NSString)
            .pathExtension
            .lowercased()
    }

    private var isShareSheetPresented:
        Binding<Bool> {
        Binding(
            get: {
                shareURL != nil
            },
            set: { isPresented in
                if !isPresented {
                    shareURL = nil
                }
            }
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            HStack(
                alignment: .top,
                spacing: 10
            ) {
                Image(
                    systemName:
                        iconForExtension(fileExtension)
                )
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 26)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(item.filename)
                        .font(
                            .subheadline.weight(.medium)
                        )
                        .lineLimit(2)

                    statusSubtitle
                }

                Spacer()

                trailingAction
            }

            if item.isActive ||
                (
                    item.received > 0 &&
                    item.progress < 1.0
                ) {
                ProgressView(value: item.progress)
                    .tint(
                        item.isActive
                        ? .accentColor
                        : .orange
                    )
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            downloadContextMenu
        }
        .sheet(
            isPresented: isShareSheetPresented
        ) {
            if let shareURL = shareURL {
                ActivityView(
    items: [shareURL]
)
            }
        }
    }

    @ViewBuilder
    private var downloadContextMenu: some View {
        if case let .completed(url) = item.state {
            Button {
                onPreview(url)
            } label: {
                Label(
                    "Preview / Open File",
                    systemImage: "eye"
                )
            }

            Button {
                onShowFolder(
                    url.deletingLastPathComponent()
                )
            } label: {
                Label(
                    "Show Container Folder",
                    systemImage: "folder"
                )
            }

            Button {
                shareURL = url
            } label: {
                Label(
                    "Share / Save to Files…",
                    systemImage:
                        "square.and.arrow.up"
                )
            }
        }

        if case .failed = item.state {
            Button {
                soulseek.retry(item)
            } label: {
                Label(
                    "Resume Download",
                    systemImage: "arrow.clockwise"
                )
            }
        }

        Button(role: .destructive) {
            soulseek.cancel(item)
        } label: {
            Label(
                "Remove Download",
                systemImage: "trash"
            )
        }
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        switch item.state {
        case .requesting:
            Text(
                "Connecting to \(item.id.username)… · " +
                "\(Formatting.bytes(item.received)) / " +
                "\(Formatting.bytes(item.size))"
            )
            .font(.caption)
            .foregroundColor(.secondary)

        case let .queued(place):
            let placeString =
                place.map {
                    "Place #\($0) in queue"
                }
                ?? "Queued"

            Text(
                "\(placeString) · " +
                "\(Formatting.bytes(item.received)) / " +
                "\(Formatting.bytes(item.size))"
            )
            .font(.caption)
            .foregroundColor(.orange)

        case .starting:
            Text(
                "Starting transfer… · " +
                "\(Formatting.bytes(item.received)) / " +
                "\(Formatting.bytes(item.size))"
            )
            .font(.caption)
            .foregroundColor(.secondary)

        case .transferring:
            let percentage =
                Int((item.progress * 100).rounded())

            Text(
                "Downloading \(percentage)% · " +
                "\(Formatting.bytes(item.received)) / " +
                "\(Formatting.bytes(item.size))"
            )
            .font(.caption)
            .foregroundColor(.secondary)

        case let .completed(url):
            Text(
                "Completed · " +
                "\(Formatting.bytes(item.size)) · " +
                url.deletingLastPathComponent()
                    .lastPathComponent
            )
            .font(.caption)
            .foregroundColor(.green)

        case let .failed(reason):
            Text(
                "\(reason) · " +
                "\(Formatting.bytes(item.received)) / " +
                "\(Formatting.bytes(item.size))"
            )
            .font(.caption)
            .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        switch item.state {
        case let .completed(url):
            HStack(spacing: 8) {
                Button {
                    onShowFolder(
                        url.deletingLastPathComponent()
                    )
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(
                    BorderlessButtonStyle()
                )

                Button {
                    if let track =
                        library.track(at: url) {
                        player.play([track])
                    } else {
                        onPreview(url)
                    }
                } label: {
                    Image(
                        systemName:
                            LibraryStore
                                .audioExtensions
                                .contains(fileExtension)
                            ? "play.circle.fill"
                            : "eye.circle.fill"
                    )
                    .font(.title3)
                }
                .buttonStyle(
                    BorderlessButtonStyle()
                )
            }

        case .failed:
            Button {
                soulseek.retry(item)
            } label: {
                Image(
                    systemName:
                        "arrow.clockwise.circle.fill"
                )
                .font(.title2)
                .foregroundColor(.orange)
            }
            .buttonStyle(
                BorderlessButtonStyle()
            )

        default:
            Button {
                soulseek.cancel(item)
            } label: {
                Image(
                    systemName: "xmark.circle.fill"
                )
                .font(.title3)
                .foregroundColor(.secondary)
            }
            .buttonStyle(
                BorderlessButtonStyle()
            )
        }
    }

    private func iconForExtension(
        _ fileExtension: String
    ) -> String {
        if LibraryStore.audioExtensions
            .contains(fileExtension) {
            return "music.note"
        }

        if LibraryStore.imageExtensions
            .contains(fileExtension) {
            return "photo"
        }

        if [
            "mp4",
            "mkv",
            "mov",
            "avi",
            "webm"
        ].contains(fileExtension) {
            return "film"
        }

        if [
            "zip",
            "rar",
            "7z",
            "tar",
            "gz"
        ].contains(fileExtension) {
            return "doc.zipper"
        }

        if [
            "pdf",
            "epub",
            "txt",
            "md"
        ].contains(fileExtension) {
            return "book"
        }

        return "doc.fill"
    }
}

// MARK: - Local folder browser

struct LocalFolderBrowserView: View {
    let folderURL: URL

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var soulseek:
        SoulseekModel
    @EnvironmentObject private var library:
        LibraryStore
    @EnvironmentObject private var player:
        Player

    @State private var contents: [URL] = []
    @State private var previewURL: URL?
    @State private var shareURL: URL?

    private var isShareSheetPresented:
        Binding<Bool> {
        Binding(
            get: {
                shareURL != nil
            },
            set: { isPresented in
                if !isPresented {
                    shareURL = nil
                }
            }
        )
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {
                        Text(
                            folderURL.lastPathComponent
                        )
                        .font(.headline)

                        Text(folderURL.path)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Button {
                    soulseek.setCustomDownloadFolder(
                        folderURL
                    )
                } label: {
                    Label(
                        "Use This Folder for Future Downloads",
                        systemImage:
                            "checkmark.folder.fill"
                    )
                }

                Button {
                    openInSystemFilesApp(folderURL)
                } label: {
                    Label(
                        "Open in iOS Files App",
                        systemImage:
                            "arrow.up.forward.app.fill"
                    )
                }

                Button {
                    shareURL = folderURL
                } label: {
                    Label(
                        "Share / Export Entire Folder…",
                        systemImage:
                            "square.and.arrow.up"
                    )
                }
            }

            Section(
                "Files in Folder (\(contents.count))"
            ) {
                if contents.isEmpty {
                    Text("This folder is empty.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(
                        contents,
                        id: \.path
                    ) { itemURL in
                        folderItemRow(itemURL)
                    }
                }
            }
        }
        .navigationTitle(
            folderURL.lastPathComponent
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .navigationBarTrailing
            ) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            reloadContents()
        }
        .sheet(
            isPresented: isShareSheetPresented
        ) {
            if let shareURL = shareURL {
                ActivityView(
    items: [shareURL]
)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    previewURL != nil
                },
                set: { isPresented in
                    if !isPresented {
                        previewURL = nil
                    }
                }
            )
        ) {
            if let previewURL = previewURL {
                QuickLookPreview(url: previewURL)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func folderItemRow(
        _ itemURL: URL
    ) -> some View {
        let resourceValues =
            try? itemURL.resourceValues(
                forKeys: [.isDirectoryKey]
            )

        let isDirectory =
            resourceValues?.isDirectory ?? false

        if isDirectory {
            NavigationLink(
                destination:
                    LocalFolderBrowserView(
                        folderURL: itemURL
                    )
            ) {
                Label(
                    itemURL.lastPathComponent,
                    systemImage: "folder.fill"
                )
            }
        } else {
            HStack {
                Button {
                    openFile(itemURL)
                } label: {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(
                                .accentColor
                            )

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(
                                itemURL
                                    .lastPathComponent
                            )
                            .foregroundColor(.primary)
                            .lineLimit(2)

                            if let size =
                                fileSize(for: itemURL) {
                                Text(
                                    Formatting.bytes(
                                        size
                                    )
                                )
                                .font(.caption)
                                .foregroundColor(
                                    .secondary
                                )
                            }
                        }
                    }
                }
                .buttonStyle(
                    PlainButtonStyle()
                )

                Spacer()

                Button {
                    shareURL = itemURL
                } label: {
                    Image(
                        systemName:
                            "square.and.arrow.up"
                    )
                }
                .buttonStyle(
                    BorderlessButtonStyle()
                )
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    try? FileManager.default
                        .removeItem(at: itemURL)

                    reloadContents()
                } label: {
                    Label(
                        "Delete",
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func openFile(_ itemURL: URL) {
        let fileExtension =
            itemURL.pathExtension.lowercased()

        if LibraryStore.audioExtensions
            .contains(fileExtension),
           let track =
               library.track(at: itemURL) {
            player.play([track])
        } else {
            previewURL = itemURL
        }
    }

    private func fileSize(
        for itemURL: URL
    ) -> UInt64? {
        let attributes =
            try? FileManager.default
                .attributesOfItem(
                    atPath: itemURL.path
                )

        if let number =
            attributes?[.size] as? NSNumber {
            return number.uint64Value
        }

        if let size =
            attributes?[.size] as? UInt64 {
            return size
        }

        return nil
    }

    private func reloadContents() {
        _ = folderURL
            .startAccessingSecurityScopedResource()

        let items =
            (
                try? FileManager.default
                    .contentsOfDirectory(
                        at: folderURL,
                        includingPropertiesForKeys: [
                            .isDirectoryKey,
                            .fileSizeKey
                        ],
                        options: [
                            .skipsHiddenFiles
                        ]
                    )
            ) ?? []

        contents = items.sorted {
            $0.lastPathComponent
                .localizedStandardCompare(
                    $1.lastPathComponent
                )
                == .orderedAscending
        }
    }

    private func openInSystemFilesApp(
        _ url: URL
    ) {
        let encodedPath =
            url.path.addingPercentEncoding(
                withAllowedCharacters:
                    .urlPathAllowed
            )
            ?? url.path

        guard let sharedURL = URL(
            string:
                "shareddocuments://\(encodedPath)"
        ) else {
            return
        }

        UIApplication.shared.open(sharedURL)
    }
}

// MARK: - Folder document picker

struct FolderDocumentPicker:
    UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (URL) -> Void

    init(
        isPresented: Binding<Bool> =
            .constant(true),
        onPick: @escaping (URL) -> Void
    ) {
        _isPresented = isPresented
        self.onPick = onPick
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {
        let picker =
            UIDocumentPickerViewController(
                forOpeningContentTypes: [.folder],
                asCopy: false
            )

        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true

        picker.directoryURL =
            FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first

        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController:
            UIDocumentPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator:
        NSObject,
        UIDocumentPickerDelegate {
        let parent: FolderDocumentPicker

        init(parent: FolderDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(
            _ controller:
                UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let first = urls.first else {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }

                return
            }

            DispatchQueue.main.async {
                self.parent.onPick(first)
                self.parent.isPresented = false
                controller.dismiss(animated: true)
            }
        }

        func documentPickerWasCancelled(
            _ controller:
                UIDocumentPickerViewController
        ) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
                controller.dismiss(animated: true)
            }
        }
    }
}

// MARK: - iOS 15 share sheet

    func updateUIViewController(
        _ uiViewController:
            UIActivityViewController,
        context: Context
    ) {
    }
}
