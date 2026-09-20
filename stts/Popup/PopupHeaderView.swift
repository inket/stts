//
//  PopupHeaderView.swift
//  stts
//

import SwiftUI

/// The pinned top block: the crown band, or a plain text verdict for the states it doesn't cover,
/// then a proportional status bar and a legend naming each bucket in it.
struct PopupHeaderView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBlock

            statusBar

            if showsLegend {
                legend
                    .padding(PopupLayout.Legend.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        PopupLayout.Colors.hairline.swiftUI.frame(height: PopupLayout.hairlineWidth)
                    }
            }

            if viewModel.isFullyUnreachable {
                retryLine
                    .padding(.horizontal, PopupLayout.Crown.padding.leading)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top block

    @ViewBuilder
    private var topBlock: some View {
        if viewModel.usesCrownHeader {
            PopupCrownHeaderView(viewModel: viewModel, onRefresh: onRefresh)
        } else {
            plainVerdict
        }
    }

    private var plainVerdict: some View {
        HStack(spacing: PopupLayout.Crown.contentGap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verdictText)
                    .font(PopupLayout.Fonts.verdictTitle.swiftUI)
                    .foregroundColor(PopupLayout.Colors.verdictLabel.swiftUI)

                Text(subtitleText)
                    .font(PopupLayout.Fonts.crownSubtitle.swiftUI)
                    .foregroundColor(PopupLayout.Colors.timestampLabel.swiftUI)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PopupLayout.Crown.padding)
    }

    private var verdictText: String {
        viewModel.isFullyUnreachable ? "No connection" : "All systems operational"
    }

    private var subtitleText: String {
        if viewModel.checkState.isChecking {
            return "Checking…"
        }

        if viewModel.isFullyUnreachable {
            guard let lastSuccessfulUpdate = viewModel.lastSuccessfulUpdate else {
                return "No successful check yet"
            }
            return "Last successful check \(Self.relativeDescription(of: lastSuccessfulUpdate))"
        }

        guard let lastUpdated = viewModel.lastUpdated else { return " " }

        return "Checked \(Self.relativeDescription(of: lastUpdated))"
    }

    // MARK: - Status bar

    /// Sits flush against the band above it, separated only by a 1pt seam that reads as the band's
    /// own shadow.
    private var statusBar: some View {
        GeometryReader { proxy in
            Group {
                if case let .checking(completed, total) = viewModel.checkState {
                    checkingBar(completed: completed, total: total, availableWidth: proxy.size.width)
                } else {
                    segmentedBar(availableWidth: proxy.size.width)
                }
            }
        }
        .frame(height: PopupLayout.StatusBar.height)
        .overlay(alignment: .top) {
            PopupLayout.Colors.crownSeam.swiftUI.frame(height: 1)
        }
    }

    private func segmentedBar(availableWidth: CGFloat) -> some View {
        let segments = buckets
        let gaps = CGFloat(max(segments.count - 1, 0)) * PopupLayout.StatusBar.segmentGap
        let usable = max(availableWidth - gaps, 0)
        let total = max(viewModel.totalCount, 1)

        return HStack(spacing: PopupLayout.StatusBar.segmentGap) {
            ForEach(segments) { bucket in
                Rectangle()
                    .fill(bucket.color.swiftUI)
                    .frame(width: usable * Double(bucket.count) / Double(total))
            }
        }
    }

    /// While a check is running the bar becomes a progress track: how many services have reported
    /// so far, rather than what they reported.
    private func checkingBar(completed: Int, total: Int, availableWidth: CGFloat) -> some View {
        let fraction = total > 0 ? Double(completed) / Double(total) : 0

        return ZStack(alignment: .leading) {
            Rectangle().fill(PopupLayout.Colors.statusBarTrack.swiftUI)

            Rectangle()
                .fill(PopupLayout.Colors.crownOperational.swiftUI)
                .frame(width: availableWidth * fraction)
        }
    }

    // MARK: - Legend

    private struct Bucket: Identifiable {
        let id: String
        let color: NSColor
        let count: Int
        let noun: String
    }

    /// Only non-empty buckets appear, in severity order. The legend's noun for the healthy bucket
    /// is "up" — the roster row below says "operational" instead.
    private var buckets: [Bucket] {
        [
            Bucket(id: "major", color: PopupLayout.Colors.crownMajor, count: viewModel.majorCount, noun: "major"),
            Bucket(id: "minor", color: PopupLayout.Colors.crownMinor, count: viewModel.minorCount, noun: "minor"),
            Bucket(
                id: "maintenance",
                color: PopupLayout.Colors.crownMaintenance,
                count: viewModel.maintenanceCount,
                noun: "maintenance"
            ),
            Bucket(
                id: "unknown",
                color: PopupLayout.Colors.unknownBar,
                count: viewModel.unknownCount,
                noun: "unknown"
            ),
            Bucket(
                id: "operational",
                color: PopupLayout.Colors.crownOperational,
                count: viewModel.operationalCount,
                noun: "up"
            )
        ].filter { $0.count > 0 }
    }

    /// Dropped for the all-clear crown: a lone "16 up" repeats what the crown and the bar already
    /// say.
    private var showsLegend: Bool {
        if case .checking = viewModel.checkState { return true }
        return !viewModel.isAllClear
    }

    private var legend: some View {
        Group {
            if case let .checking(completed, total) = viewModel.checkState {
                legendItem(
                    color: PopupLayout.Colors.unknownBar,
                    label: "\(completed) of \(total) checked"
                )
            } else {
                // Wraps rather than clipping: with maintenance and unknown both present the five
                // possible entries are wider than the popup.
                LegendFlowLayout(spacing: PopupLayout.Legend.itemsGap, lineSpacing: 6) {
                    ForEach(buckets) { bucket in
                        legendItem(color: bucket.color, label: "\(bucket.count) \(bucket.noun)")
                    }
                }
            }
        }
    }

    private func legendItem(color: NSColor, label: String) -> some View {
        HStack(spacing: PopupLayout.Legend.swatchGap) {
            RoundedRectangle(cornerRadius: PopupLayout.Legend.swatchCornerRadius, style: .continuous)
                .fill(color.swiftUI)
                .frame(width: PopupLayout.Legend.swatchSize, height: PopupLayout.Legend.swatchSize)

            Text(label)
                .font(PopupLayout.Fonts.legend.swiftUI)
                .foregroundColor(PopupLayout.Colors.legendLabel.swiftUI)
                .fixedSize()
        }
    }

    // MARK: - Retry

    private var retryLine: some View {
        HStack(spacing: 6) {
            Text("stts will retry automatically")
                .font(PopupLayout.Fonts.noConnectionNote.swiftUI)
                .foregroundColor(PopupLayout.Colors.serviceMessage.swiftUI)

            Text("·")
                .foregroundColor(PopupLayout.Colors.separatorDot.swiftUI)

            Button(action: onRefresh) {
                Text("Retry now")
                    .font(PopupLayout.Fonts.noConnectionNote.swiftUI)
                    .foregroundColor(PopupLayout.Colors.link.swiftUI)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Formatting

    private static func relativeDescription(of date: Date) -> String {
        // Guard against the formatter rendering "in 0 sec." for a check that just landed.
        let reference = Int(date.timeIntervalSince1970) == Int(Date().timeIntervalSince1970)
            ? Date(timeIntervalSinceNow: -1)
            : date

        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short

        return formatter.localizedString(for: reference, relativeTo: Date())
    }
}

/// Minimal flow layout: lays children out left to right, wrapping to a new line when the next child
/// wouldn't fit. Only used by the legend, which is the one row here that can exceed the popup width.
private struct LegendFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: maxWidth)

        let height = rows.reduce(into: CGFloat.zero) { total, row in
            total += row.height
        } + CGFloat(max(rows.count - 1, 0)) * lineSpacing

        let width = rows.map(\.width).max() ?? 0

        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if !current.indices.isEmpty, advance > maxWidth {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = advance
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}
