import SoulseekKit
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var soulseek: SoulseekModel
    @EnvironmentObject private var router: AppRouter

    @State private var query = ""
    @State private var keywordFilter = ""
    @State private var isSearchFocused = false
    @State private var showFilters = false
    @State private var showPeersSheet = false

    private var displayedResults: [FolderResult] {
        let trimmed = keywordFilter
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !trimmed.isEmpty else {
            return soulseek.results
        }

        let terms = trimmed
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        return soulseek.results.filter { folder in
            let folderText =
                "\(folder.folder) \(folder.username)"
                .lowercased()

            return terms.allSatisfy { term in
                if folderText.contains(term) {
                    return true
                }

                return folder.files.contains {
                    $0.filename
                        .lowercased()
                        .contains(term)
                }
            }
        }
    }

    private var matchingHistory: [String] {
        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return soulseek.searchHistory
        }

        return soulseek.searchHistory.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var shouldShowHomeSections: Bool {
        isSearchFocused || soulseek.currentQuery.isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                if !soulseek.isLoggedIn {
                    Section {
                        ConnectionBanner()
                    }
                }

                wishlistSection
                favoriteUsersSection
                searchHistorySection
                activeSearchResults
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Search")
            .searchable(
                text: $query,
                prompt:
                    "Search any file, album, zip, book…"
            )
            .onSubmit(of: .search) {
                keywordFilter = ""
                isSearchFocused = false
                soulseek.search(query)
            }
            .onReceive(
                router.$pendingSearch
            ) { pending in
                guard let pending = pending else {
                    return
                }

                query = pending
                keywordFilter = ""
                isSearchFocused = false
                soulseek.search(pending)
                router.pendingSearch = nil
            }
            .toolbar {
                ToolbarItemGroup(
                    placement: .navigationBarTrailing
                ) {
                    Button {
                        showPeersSheet = true
                    } label: {
                        Image(
                            systemName:
                                "person.2.crop.square.stack"
                        )
                    }

                    Button {
                        showFilters = true
                    } label: {
                        Image(
                            systemName:
                                soulseek.filters.activeCount > 0 ||
                                soulseek.audioOnly
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .sheet(
                isPresented: $showFilters
            ) {
                SearchFiltersView()
            }
            .sheet(
                isPresented: $showPeersSheet
            ) {
                PeersManagerSheet()
            }
            .overlay {
                if soulseek.currentQuery.isEmpty &&
                    soulseek.searchHistory.isEmpty &&
                    soulseek.wishlist.isEmpty &&
                    soulseek.isLoggedIn &&
                    !isSearchFocused {
                    EmptyStateView(
                        title: "Search Soulseek",
                        message:
                            "Search for music, videos, " +
                            "archives, books or any file. " +
                            "Results arrive over about " +
                            "30 seconds.",
                        systemImage: "magnifyingglass"
                    )
                }
            }
        }
    }

    // MARK: - Wishlist

    @ViewBuilder
    private var wishlistSection: some View {
        if shouldShowHomeSections &&
            !soulseek.wishlist.isEmpty {
            Section {
                ForEach(soulseek.wishlist) { item in
                    Button {
                        query = item.query
                        keywordFilter = ""
                        isSearchFocused = false
                        soulseek.search(item.query)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)

                            VStack(
                                alignment: .leading,
                                spacing: 2
                            ) {
                                Text(item.query)
                                    .font(
                                        .subheadline
                                            .weight(.medium)
                                    )
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                if let checked =
                                    item.lastChecked {
                                    Text(
                                        "Checked " +
                                        checked.formatted(
                                            .relative(
                                                presentation:
                                                    .named
                                            )
                                        )
                                    )
                                    .font(.caption2)
                                    .foregroundColor(
                                        .secondary
                                    )
                                }
                            }

                            Spacer()

                            if item.lastMatchCount > 0 {
                                Text(
                                    "\(item.lastMatchCount) hits"
                                )
                                .font(
                                    .caption
                                        .weight(.semibold)
                                )
                                .padding(
                                    .horizontal,
                                    8
                                )
                                .padding(
                                    .vertical,
                                    3
                                )
                                .background(
                                    Color.green.opacity(0.2),
                                    in: Capsule()
                                )
                                .foregroundColor(.green)
                            }
                        }
                    }
                    .swipeActions(
                        edge: .trailing
                    ) {
                        Button(
                            role: .destructive
                        ) {
                            soulseek
                                .removeWishlistItem(
                                    item
                                )
                        } label: {
                            Label(
                                "Remove",
                                systemImage: "trash"
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Label(
                        "Wishlist",
                        systemImage:
                            "star.circle.fill"
                    )

                    Spacer()

                    Button {
                        soulseek.checkAllWishlist()
                    } label: {
                        if soulseek
                            .isCheckingWishlist {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Check All")
                        }
                    }
                    .font(
                        .caption.weight(.semibold)
                    )
                    .textCase(nil)
                    .disabled(
                        !soulseek.isLoggedIn ||
                        soulseek.isCheckingWishlist
                    )
                }
            }
        }
    }

    // MARK: - Favorite users

    @ViewBuilder
    private var favoriteUsersSection: some View {
        if shouldShowHomeSections &&
            !soulseek.favoriteUsers.isEmpty {
            Section(
                "Favorite Users (Tap to Browse)"
            ) {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 8) {
                        ForEach(
                            soulseek.favoriteUsers,
                            id: \.self
                        ) { user in
                            NavigationLink(
                                destination:
                                    RemoteFolderBrowserView(
                                        target:
                                            BrowseTarget(
                                                username:
                                                    user,
                                                folder: ""
                                            )
                                    )
                            ) {
                                Label(
                                    user,
                                    systemImage:
                                        "person.crop.circle.badge.checkmark"
                                )
                                .font(
                                    .caption
                                        .weight(.semibold)
                                )
                                .padding(
                                    .horizontal,
                                    12
                                )
                                .padding(
                                    .vertical,
                                    7
                                )
                                .background(
                                    Color.accentColor
                                        .opacity(0.15),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(
                                PlainButtonStyle()
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var searchHistorySection: some View {
        if shouldShowHomeSections &&
            !matchingHistory.isEmpty {
            Section {
                ForEach(
                    matchingHistory,
                    id: \.self
                ) { item in
                    Button {
                        query = item
                        keywordFilter = ""
                        isSearchFocused = false
                        soulseek.search(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName:
                                    "clock.arrow.circlepath"
                            )
                            .foregroundColor(.secondary)

                            Text(item)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                soulseek
                                    .toggleWishlist(item)
                            } label: {
                                Image(
                                    systemName:
                                        soulseek
                                            .isInWishlist(
                                                item
                                            )
                                        ? "star.fill"
                                        : "star"
                                )
                                .foregroundColor(
                                    soulseek
                                        .isInWishlist(
                                            item
                                        )
                                    ? .yellow
                                    : .secondary
                                )
                            }
                            .buttonStyle(
                                PlainButtonStyle()
                            )
                        }
                    }
                    .swipeActions(
                        edge: .trailing
                    ) {
                        Button(
                            role: .destructive
                        ) {
                            soulseek
                                .removeSearchHistoryItem(
                                    item
                                )
                        } label: {
                            Label(
                                "Delete",
                                systemImage: "trash"
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")

                    Spacer()

                    Button("Clear") {
                        soulseek.clearSearchHistory()
                    }
                    .font(
                        .caption.weight(.semibold)
                    )
                    .textCase(nil)
                }
            }
        }
    }

    // MARK: - Active results

    @ViewBuilder
    private var activeSearchResults: some View {
        if !soulseek.currentQuery.isEmpty &&
            !isSearchFocused {
            Section {
                FilterChips(
                    showAll: $showFilters
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                HStack(spacing: 8) {
                    Image(
                        systemName:
                            "line.3.horizontal.decrease"
                    )
                    .foregroundColor(.secondary)

                    TextField(
                        "Filter results by keyword, " +
                        "file or user…",
                        text: $keywordFilter
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if !keywordFilter.isEmpty {
                        Button {
                            keywordFilter = ""
                        } label: {
                            Image(
                                systemName:
                                    "xmark.circle.fill"
                            )
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(
                            PlainButtonStyle()
                        )
                    }

                    Divider()
                        .frame(height: 18)

                    Button {
                        soulseek.toggleWishlist(
                            soulseek.currentQuery
                        )
                    } label: {
                        Label(
                            soulseek.isInWishlist(
                                soulseek.currentQuery
                            )
                            ? "Saved"
                            : "Wishlist",
                            systemImage:
                                soulseek.isInWishlist(
                                    soulseek.currentQuery
                                )
                                ? "star.fill"
                                : "star"
                        )
                        .font(
                            .caption
                                .weight(.semibold)
                        )
                        .foregroundColor(
                            soulseek.isInWishlist(
                                soulseek.currentQuery
                            )
                            ? .yellow
                            : .accentColor
                        )
                    }
                    .buttonStyle(
                        PlainButtonStyle()
                    )
                }
                .padding(.vertical, 2)
            }

            Section {
                HStack {
                    Text(
                        "\(soulseek.responseCount) users · " +
                        "\(displayedResults.count) folders"
                    )

                    if soulseek.hiddenCount > 0 {
                        Text(
                            "· \(soulseek.hiddenCount) " +
                            "filtered out"
                        )
                    }

                    Spacer()

                    if soulseek.filters.activeCount > 0 ||
                        soulseek.audioOnly ||
                        !keywordFilter.isEmpty {
                        Button("Clear Filters") {
                            soulseek.audioOnly = false
                            keywordFilter = ""

                            soulseek.filters =
                                ResultFilters(
                                    sort:
                                        soulseek
                                            .filters
                                            .sort
                                )
                        }
                        .font(
                            .footnote
                                .weight(.semibold)
                        )
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }

            ForEach(displayedResults) { folder in
                NavigationLink(
                    destination:
                        FolderDetailView(
                            folderID: folder.id
                        )
                ) {
                    FolderRow(
                        folder: folder,
                        isFavorite:
                            soulseek.isFavoriteUser(
                                folder.username
                            )
                    )
                }
                .contextMenu {
                    NavigationLink(
                        destination:
                            RemoteFolderBrowserView(
                                target:
                                    BrowseTarget(
                                        username:
                                            folder.username,
                                        folder:
                                            folder.folder
                                    )
                            )
                    ) {
                        Label(
                            "Browse Full Folder",
                            systemImage: "folder"
                        )
                    }

                    if let parent =
                        folder.parentFolderPath {
                        NavigationLink(
                            destination:
                                RemoteFolderBrowserView(
                                    target:
                                        BrowseTarget(
                                            username:
                                                folder
                                                    .username,
                                            folder:
                                                parent
                                        )
                                )
                        ) {
                            Label(
                                "Browse Parent Folder",
                                systemImage:
                                    "folder.badge.gearshape"
                            )
                        }
                    }

                    NavigationLink(
                        destination:
                            RemoteFolderBrowserView(
                                target:
                                    BrowseTarget(
                                        username:
                                            folder.username,
                                        folder: ""
                                    )
                            )
                    ) {
                        Label(
                            "Browse All User Files " +
                            "(\(folder.username))",
                            systemImage:
                                "externaldrive.fill.badge.person.crop"
                        )
                    }

                    Button {
                        soulseek.downloadFolder(folder)
                    } label: {
                        Label(
                            "Download Folder",
                            systemImage:
                                "arrow.down.circle"
                        )
                    }

                    Divider()

                    Button {
                        soulseek.toggleFavoriteUser(
                            folder.username
                        )
                    } label: {
                        Label(
                            soulseek.isFavoriteUser(
                                folder.username
                            )
                            ? "Remove Favorite User"
                            : "Favorite User " +
                                "(\(folder.username))",
                            systemImage:
                                soulseek.isFavoriteUser(
                                    folder.username
                                )
                                ? "star.slash"
                                : "star"
                        )
                    }

                    Button(
                        role: .destructive
                    ) {
                        soulseek.toggleBlockedUser(
                            folder.username
                        )
                    } label: {
                        Label(
                            "Block User " +
                            "(\(folder.username))",
                            systemImage:
                                "hand.raised.fill"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Peer management

struct PeersManagerSheet: View {
    @EnvironmentObject private var soulseek:
        SoulseekModel
    @Environment(\.dismiss) private var dismiss

    @State private var newUsername = ""

    var body: some View {
        NavigationView {
            List {
                Section("Add User Manually") {
                    HStack {
                        TextField(
                            "Soulseek username…",
                            text: $newUsername
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button("Favorite") {
                            let trimmed =
                                newUsername
                                    .trimmingCharacters(
                                        in: .whitespaces
                                    )

                            guard !trimmed.isEmpty else {
                                return
                            }

                            if !soulseek
                                .isFavoriteUser(
                                    trimmed
                                ) {
                                soulseek
                                    .toggleFavoriteUser(
                                        trimmed
                                    )
                            }

                            newUsername = ""
                        }
                        .buttonStyle(
                            BorderedProminentButtonStyle()
                        )
                        .controlSize(.small)
                        .disabled(
                            newUsername
                                .trimmingCharacters(
                                    in: .whitespaces
                                )
                                .isEmpty
                        )
                    }
                }

                Section(
                    "Favorite Users " +
                    "(\(soulseek.favoriteUsers.count))"
                ) {
                    if soulseek.favoriteUsers.isEmpty {
                        Text(
                            "Long-press a search result " +
                            "folder to favorite a user."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        ForEach(
                            soulseek.favoriteUsers,
                            id: \.self
                        ) { user in
                            HStack {
                                Label(
                                    user,
                                    systemImage:
                                        "star.fill"
                                )
                                .foregroundColor(.primary)

                                Spacer()

                                Button(
                                    "Remove",
                                    role: .destructive
                                ) {
                                    soulseek
                                        .toggleFavoriteUser(
                                            user
                                        )
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                Section(
                    "Blocked Users / Blacklist " +
                    "(\(soulseek.blockedUsers.count))"
                ) {
                    if soulseek.blockedUsers.isEmpty {
                        Text(
                            "Blocked users are hidden " +
                            "from search results."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        ForEach(
                            soulseek.blockedUsers,
                            id: \.self
                        ) { user in
                            HStack {
                                Label(
                                    user,
                                    systemImage:
                                        "hand.raised.fill"
                                )
                                .foregroundColor(.red)

                                Spacer()

                                Button("Unblock") {
                                    soulseek
                                        .toggleBlockedUser(
                                            user
                                        )
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle(
                "Favorite & Blocked Users"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Folder row

struct FolderRow: View {
    let folder: FolderResult
    var isFavorite: Bool = false

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            ArtworkView(
                source:
                    .remote(folder.coverQuery),
                size: 60,
                cornerRadius: 6
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(2)

                if !folder.parentPath.isEmpty {
                    HStack(spacing: 4) {
                        Image(
                            systemName: "folder"
                        )
                        .font(.caption2)

                        Text(folder.parentPath)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(folder.formatSummary)
                    Text(
                        "\(folder.files.count) files"
                    )
                    Text(
                        Formatting.bytes(
                            folder.totalSize
                        )
                    )
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label(
                        folder.username,
                        systemImage:
                            isFavorite
                            ? "star.fill"
                            : "person"
                    )
                    .foregroundColor(
                        isFavorite
                        ? .yellow
                        : .primary
                    )
                    .lineLimit(1)

                    if folder.slotFree {
                        Label(
                            "Free slot",
                            systemImage:
                                "checkmark.circle.fill"
                        )
                        .foregroundColor(.green)
                    } else {
                        Label(
                            "Queue " +
                            "\(folder.queueLength)",
                            systemImage: "hourglass"
                        )
                        .foregroundColor(.orange)
                    }

                    Text(
                        Formatting.speed(
                            folder.speed
                        )
                    )
                }
                .font(.caption2)
                .labelStyle(
                    TitleAndIconLabelStyle()
                )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Folder details

struct FolderDetailView: View {
    let folderID: String

    @EnvironmentObject private var soulseek:
        SoulseekModel

    @State private var fileFilter = ""
    @State private var extraFiles: [SharedFile] = []
    @State private var isLoadingFullFolder = false

    private func mergedFiles(
        for folder: FolderResult
    ) -> [SharedFile] {
        var seen = Set<String>()
        var combined: [SharedFile] = []

        let allKnown =
            folder.files +
            extraFiles +
            soulseek.knownFiles(
                for: folder.username
            )

        for file in allKnown
        where file.folder.caseInsensitiveCompare(
            folder.folder
        ) == .orderedSame {
            if seen.insert(
                file.path.lowercased()
            ).inserted {
                combined.append(file)
            }
        }

        return combined.sorted {
            $0.filename.localizedStandardCompare(
                $1.filename
            ) == .orderedAscending
        }
    }

    private func childSubfolders(
        for folder: FolderResult
    ) -> [
        (
            name: String,
            fullPath: String,
            count: Int
        )
    ] {
        let prefix = folder.folder + "\\"
        let prefixLower = prefix.lowercased()

        var counts: [String: Int] = [:]
        var names: [String: String] = [:]

        let files =
            extraFiles +
            soulseek.knownFiles(
                for: folder.username
            )

        for file in files {
            if file.folder
                .lowercased()
                .hasPrefix(prefixLower) {
                let remainder =
                    file.folder
                        .dropFirst(prefix.count)

                if let next =
                    remainder
                        .split(separator: "\\")
                        .first
                        .map(String.init),
                   !next.isEmpty {
                    let key = next.lowercased()

                    counts[key, default: 0] += 1

                    if names[key] == nil {
                        names[key] = next
                    }
                }
            }
        }

        return counts.keys.compactMap { key in
            guard let name = names[key],
                  let count = counts[key] else {
                return nil
            }

            return (
                name: name,
                fullPath:
                    "\(folder.folder)\\\(name)",
                count: count
            )
        }
        .sorted {
            $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if let folder =
                soulseek.folder(
                    withID: folderID
                ) {
                folderContent(folder)
            } else {
                Text(
                    "This result is no longer available."
                )
                .foregroundColor(.secondary)
            }
        }
    }

    private func folderContent(
        _ folder: FolderResult
    ) -> some View {
        let allFolderFiles =
            mergedFiles(for: folder)

        let subfolders =
            childSubfolders(for: folder)

        let trimmedFilter =
            fileFilter.trimmingCharacters(
                in: .whitespaces
            )

        let filteredFiles =
            allFolderFiles.filter {
                trimmedFilter.isEmpty ||
                $0.filename
                    .localizedCaseInsensitiveContains(
                        trimmedFilter
                    )
            }

        return List {
            folderSummary(
                folder,
                files: allFolderFiles
            )

            folderNavigation(
                folder,
                subfolders: subfolders
            )

            folderActions(
                folder,
                files: allFolderFiles
            )

            Section(
                "Files in Folder " +
                "(\(filteredFiles.count))"
            ) {
                if allFolderFiles.count > 5 {
                    fileFilterField
                }

                ForEach(
                    filteredFiles,
                    id: \.path
                ) { file in
                    FileRow(
                        file: file,
                        username: folder.username,
                        folderImages:
                            folder.images,
                        showBrowseParent: false
                    )
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: folder.id) {
            isLoadingFullFolder = true

            soulseek.browseUserFolder(
                username: folder.username,
                folder: folder.folder
            ) { files in
                if let files = files {
                    extraFiles = files
                }

                isLoadingFullFolder = false
            }
        }
    }

    private func folderSummary(
        _ folder: FolderResult,
        files: [SharedFile]
    ) -> some View {
        Section {
            HStack(spacing: 16) {
                ArtworkView(
                    source:
                        .remote(folder.coverQuery),
                    size: 110,
                    cornerRadius: 10
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(folder.name)
                        .font(.headline)

                    Text(folder.formatSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(
                        "\(files.count) files · " +
                        Formatting.bytes(
                            files.reduce(0) {
                                $0 + $1.size
                            }
                        )
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if isLoadingFullFolder {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)

                            Text(
                                "Loading all peer files…"
                            )
                            .font(.caption2)
                            .foregroundColor(
                                .secondary
                            )
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func folderNavigation(
        _ folder: FolderResult,
        subfolders: [
            (
                name: String,
                fullPath: String,
                count: Int
            )
        ]
    ) -> some View {
        Section(
            "Container & Root Folders " +
            "(Tap to Browse)"
        ) {
            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 6) {
                    remoteFolderLink(
                        username: folder.username,
                        folder: "",
                        title: folder.username,
                        systemImage:
                            "person.crop.square.fill",
                        accent: true
                    )

                    ForEach(
                        Array(
                            folder.pathLevels
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, level in
                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)

                        remoteFolderLink(
                            username:
                                folder.username,
                            folder:
                                level.fullPath,
                            title: level.name,
                            systemImage:
                                "folder.fill",
                            accent: false
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            if let parent =
                folder.parentFolderPath {
                NavigationLink(
                    destination:
                        RemoteFolderBrowserView(
                            target:
                                BrowseTarget(
                                    username:
                                        folder.username,
                                    folder:
                                        parent
                                )
                        )
                ) {
                    Label(
                        "Go Up to Parent Folder",
                        systemImage:
                            "arrow.turn.left.up"
                    )
                }
            }

            NavigationLink(
                destination:
                    RemoteFolderBrowserView(
                        target:
                            BrowseTarget(
                                username:
                                    folder.username,
                                folder:
                                    folder.folder
                            )
                    )
            ) {
                Label(
                    "Explore Full Container Folder " +
                    "from Peer",
                    systemImage:
                        "folder.badge.magnifyingglass"
                )
            }

            NavigationLink(
                destination:
                    RemoteFolderBrowserView(
                        target:
                            BrowseTarget(
                                username:
                                    folder.username,
                                folder: ""
                            )
                    )
            ) {
                Label(
                    "Browse All Shared Folders of " +
                    folder.username,
                    systemImage:
                        "externaldrive.fill.badge.person.crop"
                )
            }
        }

        if !subfolders.isEmpty {
            Section(
                "Subfolders Inside " +
                "(\(subfolders.count))"
            ) {
                ForEach(
                    subfolders,
                    id: \.fullPath
                ) { subfolder in
                    NavigationLink(
                        destination:
                            RemoteFolderBrowserView(
                                target:
                                    BrowseTarget(
                                        username:
                                            folder.username,
                                        folder:
                                            subfolder.fullPath
                                    )
                            )
                    ) {
                        HStack(spacing: 12) {
                            Image(
                                systemName:
                                    "folder.fill"
                            )
                            .foregroundColor(
                                .accentColor
                            )

                            Text(subfolder.name)
                                .font(
                                    .subheadline
                                        .weight(.medium)
                                )

                            Spacer()

                            Text(
                                "\(subfolder.count) files"
                            )
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                        }
                    }
                }
            }
        }
    }

    private func folderActions(
        _ folder: FolderResult,
        files: [SharedFile]
    ) -> some View {
        Section {
            Button {
                soulseek.downloadFiles(
                    files,
                    from: folder.username
                )
            } label: {
                Label(
                    "Download All " +
                    "(\(files.count) files)",
                    systemImage:
                        "arrow.down.circle.fill"
                )
            }
            .disabled(!soulseek.isLoggedIn)

            Button {
                soulseek.toggleFavoriteUser(
                    folder.username
                )
            } label: {
                Label(
                    soulseek.isFavoriteUser(
                        folder.username
                    )
                    ? "Remove \(folder.username) " +
                        "from Favorites"
                    : "Add \(folder.username) " +
                        "to Favorite Users",
                    systemImage:
                        soulseek.isFavoriteUser(
                            folder.username
                        )
                        ? "star.slash"
                        : "star"
                )
            }
        } footer: {
            Text(
                "From \(folder.username) · " +
                "\(folder.folder). Tap a folder " +
                "above to navigate its directories."
            )
        }
    }

    private var fileFilterField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(
                "Filter files in this folder…",
                text: $fileFilter
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !fileFilter.isEmpty {
                Button {
                    fileFilter = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundColor(.secondary)
                }
                .buttonStyle(
                    PlainButtonStyle()
                )
            }
        }
    }

    private func remoteFolderLink(
        username: String,
        folder: String,
        title: String,
        systemImage: String,
        accent: Bool
    ) -> some View {
        NavigationLink(
            destination:
                RemoteFolderBrowserView(
                    target:
                        BrowseTarget(
                            username: username,
                            folder: folder
                        )
                )
        ) {
            Label(
                title,
                systemImage: systemImage
            )
            .font(
                .caption.weight(
                    accent
                    ? .semibold
                    : .medium
                )
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                accent
                ? Color.accentColor.opacity(0.15)
                : Color.secondary.opacity(0.15),
                in: Capsule()
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Remote folder browser

struct RemoteFolderBrowserView: View {
    let target: BrowseTarget

    @EnvironmentObject private var soulseek:
        SoulseekModel

    @State private var allPeerFiles: [SharedFile] = []
    @State private var isLoading = true
    @State private var filterText = ""

    private var currentPath: String {
        target.folder
    }

    private var folderTitle: String {
        currentPath
            .split(separator: "\\")
            .last
            .map(String.init)
        ?? target.username
    }

    private var parentPath: String? {
        let parts =
            currentPath.split(separator: "\\")

        guard parts.count > 1 else {
            return nil
        }

        return parts
            .dropLast()
            .joined(separator: "\\")
    }

    private var pathLevels: [
        (
            name: String,
            fullPath: String
        )
    ] {
        let parts =
            currentPath
                .split(separator: "\\")
                .map(String.init)

        var current = ""

        return parts.map { part in
            current =
                current.isEmpty
                ? part
                : "\(current)\\\(part)"

            return (
                name: part,
                fullPath: current
            )
        }
    }

    private var subfolders: [
        (
            name: String,
            fullPath: String,
            fileCount: Int
        )
    ] {
        let prefix =
            currentPath.isEmpty
            ? ""
            : currentPath + "\\"

        let prefixLower = prefix.lowercased()

        var counts: [String: Int] = [:]
        var originalNames: [String: String] = [:]

        for file in allPeerFiles {
            let folder = file.folder

            if currentPath.isEmpty {
                if let first =
                    folder
                        .split(separator: "\\")
                        .first
                        .map(String.init) {
                    let key = first.lowercased()

                    counts[key, default: 0] += 1

                    if originalNames[key] == nil {
                        originalNames[key] = first
                    }
                }
            } else if folder
                .lowercased()
                .hasPrefix(prefixLower) {
                let remainder =
                    folder.dropFirst(
                        prefix.count
                    )

                if let next =
                    remainder
                        .split(separator: "\\")
                        .first
                        .map(String.init),
                   !next.isEmpty {
                    let key = next.lowercased()

                    counts[key, default: 0] += 1

                    if originalNames[key] == nil {
                        originalNames[key] = next
                    }
                }
            }
        }

        let trimmed =
            filterText
                .trimmingCharacters(
                    in: .whitespaces
                )
                .lowercased()

        return counts.keys.compactMap { key in
            guard let name =
                    originalNames[key],
                  let count =
                    counts[key] else {
                return nil
            }

            if !trimmed.isEmpty &&
                !name.lowercased()
                    .contains(trimmed) {
                return nil
            }

            let full =
                currentPath.isEmpty
                ? name
                : "\(currentPath)\\\(name)"

            return (
                name: name,
                fullPath: full,
                fileCount: count
            )
        }
        .sorted {
            $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }

    private var directFiles: [SharedFile] {
        let trimmed =
            filterText
                .trimmingCharacters(
                    in: .whitespaces
                )
                .lowercased()

        return allPeerFiles.filter { file in
            guard file.folder
                .caseInsensitiveCompare(
                    currentPath
                ) == .orderedSame else {
                return false
            }

            if !trimmed.isEmpty {
                return file.filename
                    .lowercased()
                    .contains(trimmed)
            }

            return true
        }
        .sorted {
            $0.filename.localizedStandardCompare(
                $1.filename
            ) == .orderedAscending
        }
    }

    var body: some View {
        List {
            pathSection
            filterSection

            if isLoading {
                loadingSection
            }

            if !subfolders.isEmpty {
                subfoldersSection
            }

            if !directFiles.isEmpty {
                filesSection
            }

            if !isLoading &&
                subfolders.isEmpty &&
                directFiles.isEmpty {
                Section {
                    Text(
                        "No files or subfolders " +
                        "found at this level."
                    )
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(folderTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(
                placement: .navigationBarTrailing
            ) {
                Button {
                    soulseek.toggleFavoriteUser(
                        target.username
                    )
                } label: {
                    Image(
                        systemName:
                            soulseek.isFavoriteUser(
                                target.username
                            )
                            ? "star.fill"
                            : "star"
                    )
                    .foregroundColor(
                        soulseek.isFavoriteUser(
                            target.username
                        )
                        ? .yellow
                        : .primary
                    )
                }

                Button {
                    loadFolder(force: true)
                } label: {
                    Image(
                        systemName:
                            "arrow.clockwise"
                    )
                }
                .disabled(isLoading)
            }
        }
        .task(id: target.id) {
            loadFolder(force: false)
        }
    }

    private var pathSection: some View {
        Section {
            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 6) {
                    browserLink(
                        folder: "",
                        title: target.username,
                        systemImage:
                            "person.crop.square.fill",
                        accent: true
                    )

                    ForEach(
                        Array(
                            pathLevels.enumerated()
                        ),
                        id: \.offset
                    ) { _, level in
                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .font(.caption2)
                        .foregroundColor(.secondary)

                        browserLink(
                            folder: level.fullPath,
                            title: level.name,
                            systemImage:
                                "folder.fill",
                            accent: false
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            if let parent = parentPath {
                NavigationLink(
                    destination:
                        RemoteFolderBrowserView(
                            target:
                                BrowseTarget(
                                    username:
                                        target.username,
                                    folder: parent
                                )
                        )
                ) {
                    Label(
                        "Up to Parent Folder",
                        systemImage:
                            "arrow.turn.left.up"
                    )
                }
            } else if !currentPath.isEmpty {
                NavigationLink(
                    destination:
                        RemoteFolderBrowserView(
                            target:
                                BrowseTarget(
                                    username:
                                        target.username,
                                    folder: ""
                                )
                        )
                ) {
                    Label(
                        "Up to User Root " +
                        "(\(target.username))",
                        systemImage:
                            "arrow.turn.left.up"
                    )
                }
            }
        } header: {
            Text("Path Navigation")
        }
    }

    private var filterSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(
                    "Filter folders or files here…",
                    text: $filterText
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(
                        PlainButtonStyle()
                    )
                }
            }
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()

                Text(
                    "Requesting folder contents " +
                    "from \(target.username)…"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var subfoldersSection: some View {
        Section(
            "Subfolders (\(subfolders.count))"
        ) {
            ForEach(
                subfolders,
                id: \.fullPath
            ) { subfolder in
                NavigationLink(
                    destination:
                        RemoteFolderBrowserView(
                            target:
                                BrowseTarget(
                                    username:
                                        target.username,
                                    folder:
                                        subfolder.fullPath
                                )
                        )
                ) {
                    HStack(spacing: 12) {
                        Image(
                            systemName:
                                "folder.fill"
                        )
                        .font(.title3)
                        .foregroundColor(.accentColor)

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(subfolder.name)
                                .font(
                                    .body.weight(.medium)
                                )
                                .lineLimit(2)

                            Text(
                                "\(subfolder.fileCount) " +
                                "files inside"
                            )
                            .font(.caption)
                            .foregroundColor(
                                .secondary
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var filesSection: some View {
        Section {
            Button {
                soulseek.downloadFiles(
                    directFiles,
                    from: target.username
                )
            } label: {
                Label(
                    "Download All Files in This Folder " +
                    "(\(directFiles.count))",
                    systemImage:
                        "arrow.down.circle.fill"
                )
            }
            .disabled(!soulseek.isLoggedIn)

            ForEach(
                directFiles,
                id: \.path
            ) { file in
                FileRow(
                    file: file,
                    username: target.username,
                    folderImages: [],
                    showBrowseParent: false
                )
            }
        } header: {
            Text(
                "Files (\(directFiles.count))"
            )
        }
    }

    private func browserLink(
        folder: String,
        title: String,
        systemImage: String,
        accent: Bool
    ) -> some View {
        NavigationLink(
            destination:
                RemoteFolderBrowserView(
                    target:
                        BrowseTarget(
                            username:
                                target.username,
                            folder: folder
                        )
                )
        ) {
            Label(
                title,
                systemImage: systemImage
            )
            .font(
                .caption.weight(
                    accent
                    ? .semibold
                    : .medium
                )
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                accent
                ? Color.accentColor.opacity(0.15)
                : Color.secondary.opacity(0.15),
                in: Capsule()
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadFolder(force: Bool) {
        let fallback =
            soulseek.knownFiles(
                for: target.username
            )

        if !fallback.isEmpty {
            allPeerFiles = fallback
        }

        isLoading = true

        soulseek.browseUserFolder(
            username: target.username,
            folder: target.folder,
            forceRefresh: force
        ) { files in
            if let files = files,
               !files.isEmpty {
                allPeerFiles = files
            } else if allPeerFiles.isEmpty {
                allPeerFiles =
                    soulseek.knownFiles(
                        for: target.username
                    )
            }

            isLoading = false
        }
    }
}

// MARK: - File row

struct FileRow: View {
    let file: SharedFile
    let username: String
    let folderImages: [SharedFile]

    var showBrowseParent: Bool = true

    @EnvironmentObject private var soulseek:
        SoulseekModel

    @State private var shareURL: URL?

    private var isSharePresented:
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
        HStack {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(file.filename)
                    .lineLimit(2)

                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            statusButton
        }
        .contextMenu {
            Button {
                soulseek.download(
                    file,
                    from: username,
                    knownImages: folderImages
                )
            } label: {
                Label(
                    "Download File",
                    systemImage:
                        "arrow.down.circle"
                )
            }

            NavigationLink(
                destination:
                    RemoteFolderBrowserView(
                        target:
                            BrowseTarget(
                                username: username,
                                folder: file.folder
                            )
                    )
            ) {
                Label(
                    "Open Container Folder",
                    systemImage: "folder"
                )
            }
        }
        .sheet(
            isPresented: isSharePresented
        ) {
            if let shareURL = shareURL {
                ActivityView(
    items: [shareURL]
)
            }
        }
    }

    private var details: String {
        var parts: [String] = []

        let fileExtension =
            file.fileExtension.uppercased()

        if !fileExtension.isEmpty {
            parts.append(fileExtension)
        }

        parts.append(
            Formatting.bytes(file.size)
        )

        if let duration =
            file.attributes.duration {
            parts.append(
                Formatting.duration(
                    Double(duration)
                )
            )
        }

        if let bitrate =
            file.attributes.bitrate {
            parts.append("\(bitrate) kbps")
        }

        if let depth =
            file.attributes.bitDepth,
           let rate =
               file.attributes.sampleRate {
            parts.append(
                "\(depth)-bit/" +
                "\(Formatting.kilohertz(rate)) kHz"
            )
        }

        return parts.joined(
            separator: " · "
        )
    }

    @ViewBuilder
    private var statusButton: some View {
        switch soulseek.state(
            of: file,
            from: username
        ) {
        case .none, .some(.failed):
            Button {
                soulseek.download(
                    file,
                    from: username,
                    knownImages: folderImages
                )
            } label: {
                Image(
                    systemName:
                        "arrow.down.circle"
                )
                .font(.title3)
            }
            .buttonStyle(
                BorderlessButtonStyle()
            )
            .disabled(!soulseek.isLoggedIn)

        case let .some(.completed(url)):
            HStack(spacing: 10) {
                Button {
                    shareURL = url
                } label: {
                    Image(
                        systemName:
                            "square.and.arrow.up"
                    )
                    .font(.body)
                }
                .buttonStyle(
                    BorderlessButtonStyle()
                )

                Image(
                    systemName:
                        "checkmark.circle.fill"
                )
                .foregroundColor(.green)
            }

        default:
            ProgressView()
        }
    }
}

// MARK: - Search filters

struct SearchFiltersView: View {
    @EnvironmentObject private var soulseek:
        SoulseekModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(
                        "Sort By",
                        selection:
                            $soulseek.filters.sort
                    ) {
                        ForEach(
                            ResultFilters.Sort
                                .allCases
                        ) { sort in
                            Label(
                                sort.rawValue,
                                systemImage:
                                    sort.systemImage
                            )
                            .tag(sort)
                        }
                    }
                }

                Section("File Type & Quality") {
                    Picker(
                        "Category",
                        selection:
                            $soulseek
                                .filters
                                .fileType
                    ) {
                        ForEach(
                            ResultFilters.FileType
                                .allCases
                        ) { fileType in
                            Text(fileType.rawValue)
                                .tag(fileType)
                        }
                    }

                    Picker(
                        "Minimum Bitrate",
                        selection:
                            $soulseek
                                .filters
                                .minBitrate
                    ) {
                        ForEach(
                            ResultFilters
                                .bitrateChoices,
                            id: \.self
                        ) { bitrate in
                            Text(
                                bitrate == 0
                                ? "Any"
                                : "\(bitrate) kbps"
                            )
                            .tag(bitrate)
                        }
                    }

                    Toggle(
                        "Audio Formats Only",
                        isOn: $soulseek.audioOnly
                    )
                }

                Section {
                    Toggle(
                        "Free Upload Slot Only",
                        isOn:
                            $soulseek
                                .filters
                                .freeSlotOnly
                    )

                    Stepper(
                        value:
                            $soulseek
                                .filters
                                .minFiles,
                        in: 1...30
                    ) {
                        HStack {
                            Text("Minimum Files")

                            Spacer()

                            Text(
                                soulseek
                                    .filters
                                    .minFiles == 1
                                ? "Any"
                                : "\(soulseek.filters.minFiles)"
                            )
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Availability")
                } footer: {
                    Text(
                        "A minimum of around 6 files " +
                        "skips single files and finds " +
                        "larger folders or packs."
                    )
                }

                Section {
                    TextField(
                        "live, remix, sample",
                        text:
                            $soulseek
                                .filters
                                .excludeWords
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .autocorrectionDisabled()
                } header: {
                    Text("Exclude Words")
                } footer: {
                    Text(
                        "Hides folders whose path " +
                        "contains any of these words."
                    )
                }

                if !soulseek.filters.isDefault ||
                    soulseek.audioOnly {
                    Section {
                        Button(
                            "Reset Filters",
                            role: .destructive
                        ) {
                            soulseek.audioOnly = false
                            soulseek.filters =
                                ResultFilters()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter chips

struct FilterChips: View {
    @Binding var showAll: Bool

    @EnvironmentObject private var soulseek:
        SoulseekModel

    var body: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 8) {
                Menu {
                    Picker(
                        "Sort By",
                        selection:
                            $soulseek.filters.sort
                    ) {
                        ForEach(
                            ResultFilters.Sort
                                .allCases
                        ) { sort in
                            Label(
                                sort.rawValue,
                                systemImage:
                                    sort.systemImage
                            )
                            .tag(sort)
                        }
                    }
                } label: {
                    chip(
                        soulseek
                            .filters
                            .sort
                            .rawValue,
                        systemImage:
                            "arrow.up.arrow.down",
                        active: true
                    )
                }

                Menu {
                    Picker(
                        "File Type",
                        selection:
                            $soulseek
                                .filters
                                .fileType
                    ) {
                        ForEach(
                            ResultFilters.FileType
                                .allCases
                        ) { fileType in
                            Text(fileType.rawValue)
                                .tag(fileType)
                        }
                    }
                } label: {
                    chip(
                        soulseek
                            .filters
                            .fileType
                            .shortLabel,
                        systemImage: "doc",
                        active:
                            soulseek
                                .filters
                                .fileType != .any
                    )
                }

                Button {
                    soulseek.audioOnly.toggle()
                } label: {
                    chip(
                        "Audio Only",
                        systemImage:
                            "music.note",
                        active:
                            soulseek.audioOnly
                    )
                }

                Button {
                    soulseek
                        .filters
                        .freeSlotOnly
                        .toggle()
                } label: {
                    chip(
                        "Free Slot",
                        systemImage:
                            "checkmark.circle",
                        active:
                            soulseek
                                .filters
                                .freeSlotOnly
                    )
                }

                Button {
                    showAll = true
                } label: {
                    chip(
                        "More",
                        systemImage:
                            "slider.horizontal.3",
                        active: false
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func chip(
        _ title: String,
        systemImage: String,
        active: Bool
    ) -> some View {
        Label(
            title,
            systemImage: systemImage
        )
        .font(
            .subheadline.weight(.medium)
        )
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundColor(
            active
            ? .white
            : .primary
        )
        .background(
            active
            ? Color.accentColor
            : Color.secondary.opacity(0.15),
            in: Capsule()
        )
    }
}
