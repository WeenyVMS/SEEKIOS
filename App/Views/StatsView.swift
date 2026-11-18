import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var soulseek: SoulseekModel

    @State private var range = 14
    @State private var confirmReset = false

    var body: some View {
        // Read revision so the view refreshes
        // whenever statistics are saved.
        let _ = stats.revision
        let days = stats.lastDays(range)
        let totals = stats.totals

        List {
            summarySection(totals: totals)

            listeningSection(days: days)

            ranked(
                "Top Songs",
                stats.topSongs(limit: 10),
                detail: true
            )

            ranked(
                "Top Artists",
                stats.topArtists(limit: 10),
                detail: false
            )

            ranked(
                "Top Albums",
                stats.topAlbums(limit: 10),
                detail: true
            )

            soulseekSection(totals: totals)

            resetSection
        }
        .navigationTitle("Stats")
        .confirmationDialog(
            "Reset all stats?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button(
                "Reset",
                role: .destructive
            ) {
                stats.reset()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {
            }
        }
    }

    // MARK: - Summary

    private func summarySection(
        totals: StatsStore.Totals
    ) -> some View {
        Section {
            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible(),
                        spacing: 12
                    ),
                    GridItem(
                        .flexible(),
                        spacing: 12
                    )
                ],
                spacing: 12
            ) {
                tile(
                    "Listened",
                    Formatting.hours(
                        stats.totalSeconds
                    ),
                    "headphones"
                )

                tile(
                    "Plays",
                    "\(stats.totalPlays)",
                    "play.circle"
                )

                tile(
                    "Downloaded",
                    Formatting.bytes(
                        totals.downloadedBytes
                    ),
                    "arrow.down.circle"
                )

                tile(
                    "Uploaded",
                    Formatting.bytes(
                        totals.uploadedBytes
                    ),
                    "arrow.up.circle"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Listening chart

    private func listeningSection(
        days: [StatsStore.Day]
    ) -> some View {
        let totalSeconds =
            days.reduce(0.0) {
                partial,
                day in

                partial + day.minutes * 60
            }

        let averageSeconds =
            totalSeconds /
            Double(max(range, 1))

        return Section {
            Picker(
                "Range",
                selection: $range
            ) {
                Text("7 Days")
                    .tag(7)

                Text("14 Days")
                    .tag(14)

                Text("30 Days")
                    .tag(30)
            }
            .pickerStyle(
                SegmentedPickerStyle()
            )

            ListeningBarChart(days: days)
                .frame(height: 190)
                .padding(.vertical, 8)

            StatsLabeledRow(
                title: "This period",
                value:
                    Formatting.hours(
                        totalSeconds
                    )
            )

            StatsLabeledRow(
                title: "Daily average",
                value:
                    Formatting.hours(
                        averageSeconds
                    )
            )
        } header: {
            Text("Listening")
        }
    }

    // MARK: - Soulseek statistics

    private func soulseekSection(
        totals: StatsStore.Totals
    ) -> some View {
        Section {
            StatsLabeledRow(
                title: "Songs downloaded",
                value:
                    "\(totals.downloadedFiles)"
            )

            StatsLabeledRow(
                title: "Songs uploaded",
                value:
                    "\(totals.uploadedFiles)"
            )

            StatsLabeledRow(
                title:
                    "People you've shared with",
                value:
                    "\(totals.peers.count)"
            )

            StatsLabeledRow(
                title: "Share ratio",
                value: ratio(totals)
            )

            StatsLabeledRow(
                title: "Shared right now",
                value:
                    "\(library.tracks.count) songs"
            )

            StatsLabeledRow(
                title: "Uploaded this session",
                value:
                    Formatting.bytes(
                        stats.sessionUploadedBytes
                    )
            )

            StatsLabeledRow(
                title: "Counting since",
                value:
                    formattedDate(totals.since)
            )
        } header: {
            Text("Soulseek")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(
                "Reset Stats",
                role: .destructive
            ) {
                confirmReset = true
            }
        } footer: {
            Text(
                "Stats stay on this iPhone. " +
                "A play counts after 30 seconds, " +
                "or after half of a shorter song."
            )
        }
    }

    // MARK: - Ratio

    private func ratio(
        _ totals: StatsStore.Totals
    ) -> String {
        guard totals.downloadedBytes > 0 else {
            return totals.uploadedBytes > 0
                ? "∞"
                : "–"
        }

        return String(
            format: "%.2f",
            Double(totals.uploadedBytes) /
                Double(totals.downloadedBytes)
        )
    }

    // MARK: - Date formatting

    private func formattedDate(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }

    // MARK: - Summary tile

    private func tile(
        _ title: String,
        _ value: String,
        _ symbol: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Image(systemName: symbol)
                .foregroundColor(.accentColor)

            Text(value)
                .font(
                    .title2.weight(.bold)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            Color(
                UIColor
                    .secondarySystemGroupedBackground
            ),
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    // MARK: - Rankings

    @ViewBuilder
    private func ranked(
        _ title: String,
        _ items: [StatsStore.Ranked],
        detail: Bool
    ) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(
                    Array(items.enumerated()),
                    id: \.offset
                ) {
                    index,
                    item in

                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(
                                .subheadline
                                    .monospacedDigit()
                                    .weight(.semibold)
                            )
                            .foregroundColor(.secondary)
                            .frame(
                                width: 22,
                                alignment: .trailing
                            )

                        VStack(
                            alignment: .leading,
                            spacing: 1
                        ) {
                            Text(item.name)
                                .lineLimit(1)

                            if detail &&
                                !item.detail.isEmpty {
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundColor(
                                        .secondary
                                    )
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        VStack(
                            alignment: .trailing,
                            spacing: 1
                        ) {
                            Text(
                                "\(item.plays) plays"
                            )
                            .font(
                                .caption
                                    .monospacedDigit()
                            )

                            Text(
                                Formatting.hours(
                                    item.seconds
                                )
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - iOS 15 listening chart

struct ListeningBarChart: View {
    let days: [StatsStore.Day]

    private var maximumMinutes: Double {
        max(
            days.map(\.minutes).max() ?? 0,
            1
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack {
                Text(
                    "\(Int(maximumMinutes.rounded())) min"
                )

                Spacer()

                Text("min")
            }
            .font(.caption2)
            .foregroundColor(.secondary)

            GeometryReader { geometry in
                let availableWidth =
                    geometry.size.width

                let spacing: CGFloat = 4

                let totalSpacing =
                    CGFloat(
                        max(days.count - 1, 0)
                    ) * spacing

                let barWidth =
                    max(
                        3,
                        (
                            availableWidth -
                            totalSpacing
                        ) /
                        CGFloat(
                            max(days.count, 1)
                        )
                    )

                HStack(
                    alignment: .bottom,
                    spacing: spacing
                ) {
                    ForEach(
                        Array(days.enumerated()),
                        id: \.offset
                    ) {
                        _,
                        day in

                        ListeningBar(
                            day: day,
                            maximumMinutes:
                                maximumMinutes,
                            width: barWidth,
                            availableHeight:
                                geometry.size.height
                        )
                    }
                }
            }
            .frame(height: 135)

            chartDateLabels
        }
        .accessibilityElement(
            children: .contain
        )
    }

    private var chartDateLabels: some View {
        HStack {
            if let first = days.first {
                Text(
                    shortDate(first.date)
                )
            }

            Spacer()

            if days.count > 2 {
                let middleIndex =
                    days.count / 2

                Text(
                    shortDate(
                        days[middleIndex].date
                    )
                )

                Spacer()
            }

            if let last = days.last,
               days.count > 1 {
                Text(
                    shortDate(last.date)
                )
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func shortDate(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"

        return formatter.string(
            from: date
        )
    }
}

// MARK: - One chart bar

private struct ListeningBar: View {
    let day: StatsStore.Day
    let maximumMinutes: Double
    let width: CGFloat
    let availableHeight: CGFloat

    private var barHeight: CGFloat {
        let fraction =
            min(
                max(
                    day.minutes /
                    maximumMinutes,
                    0
                ),
                1
            )

        if day.minutes <= 0 {
            return 2
        }

        return max(
            4,
            CGFloat(fraction) *
                availableHeight
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .fill(Color.accentColor)
            .frame(
                width: width,
                height: barHeight
            )
            .accessibilityLabel(
                longDate(day.date)
            )
            .accessibilityValue(
                "\(Int(day.minutes.rounded())) minutes"
            )
        }
        .frame(
            width: width,
            height: availableHeight
        )
    }

    private func longDate(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(
            from: date
        )
    }
}

// MARK: - iOS 15 labeled row

private struct StatsLabeledRow: View {
    let title: String
    let value: String

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

// MARK: - Compact Settings preview

struct StatsPreview: View {
    @EnvironmentObject private var stats:
        StatsStore

    var body: some View {
        let _ = stats.revision

        HStack(spacing: 14) {
            Image(
                systemName: "chart.bar.xaxis"
            )
            .font(.title2)
            .foregroundColor(.accentColor)
            .frame(width: 30)

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text("Stats")

                Text(
                    "\(Formatting.hours(" +
                    "stats.seconds(inLast: 7))) " +
                    "this week · ↑ " +
                    "\(Formatting.bytes(" +
                    "stats.totals.uploadedBytes)) " +
                    "shared"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}
