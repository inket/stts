//
//  PopupCrownHeaderView.swift
//  stts
//

import SwiftUI

/// The colour band at the top of the popup, tinted by the worst severity present. Either a count
/// with "N services affected / of M monitored", or — when nothing is wrong — a headline (one of six,
/// picked once per popup open) with a subtitle stating what was actually observed.
///
/// Sized like a native window header rather than a poster: the count is 34pt, not 54pt, and the
/// refresh control lives here beside the timestamp rather than in the footer.
struct PopupCrownHeaderView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: PopupLayout.Crown.contentGap) {
            if viewModel.isAllClear {
                allClearLabels
            } else {
                countLabels
            }

            Spacer(minLength: PopupLayout.Crown.contentGap)

            HStack(spacing: PopupLayout.Crown.trailingGap) {
                if let timestamp {
                    Text(timestamp)
                        .font(PopupLayout.Fonts.crownTimestamp.swiftUI)
                        .foregroundColor(PopupLayout.Colors.crownSecondaryLabel.swiftUI)
                }

                PopupCrownRefreshButton(isChecking: viewModel.checkState.isChecking, action: onRefresh)
            }
            .fixedSize()
        }
        .padding(viewModel.isAllClear ? PopupLayout.Crown.allClearPadding : PopupLayout.Crown.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.swiftUI)
    }

    // MARK: - Labels

    private var countLabels: some View {
        HStack(spacing: PopupLayout.Crown.contentGap) {
            Text("\(viewModel.affectedCount)")
                .font(PopupLayout.Fonts.crownNumber.swiftUI)
                .tracking(PopupLayout.Fonts.crownNumberKerning)
                .foregroundColor(PopupLayout.Colors.crownLabel.swiftUI)
                .fixedSize()

            VStack(alignment: .leading, spacing: 0) {
                Text(headlineText)
                    .font(PopupLayout.Fonts.crownTitle.swiftUI)
                    .foregroundColor(PopupLayout.Colors.crownLabel.swiftUI)

                Text("of \(viewModel.totalCount) monitored")
                    .font(PopupLayout.Fonts.crownSubtitle.swiftUI)
                    .foregroundColor(PopupLayout.Colors.crownSecondaryLabel.swiftUI)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "in maintenance" only when every affected service is under maintenance — a mix that includes
    /// any major/minor incident reads as "affected" even if maintenance is part of the mix.
    private var headlineText: String {
        let noun = viewModel.affectedCount == 1 ? "Service" : "Services"
        let situation = viewModel.worstIncidentKind == .maintenance ? "in maintenance" : "affected"

        return "\(noun) \(situation)"
    }

    private var allClearLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.allClearHeadline)
                .font(PopupLayout.Fonts.allClearHeadline.swiftUI)
                .tracking(PopupLayout.Fonts.allClearHeadlineKerning)
                .foregroundColor(PopupLayout.Colors.crownLabel.swiftUI)

            Text("ALL \(viewModel.operationalCount) REPORTING NO ISSUES")
                .font(PopupLayout.Fonts.allClearSubtitle.swiftUI)
                .tracking(PopupLayout.Fonts.allClearSubtitleKerning)
                .foregroundColor(PopupLayout.Colors.crownSecondaryLabel.swiftUI)
                .padding(.top, PopupLayout.Crown.allClearSubtitleTopMargin)
        }
    }

    // MARK: - Shared

    /// Also used for the popup's arrow, so the band appears to continue up into the menu bar.
    static func color(for viewModel: PopupViewModel) -> NSColor {
        switch viewModel.worstIncidentKind {
        case .major: return PopupLayout.Colors.crownMajor
        case .minor: return PopupLayout.Colors.crownMinor
        case .maintenance: return PopupLayout.Colors.crownMaintenance
        case .unknown, nil: return PopupLayout.Colors.crownOperational
        }
    }

    private var color: NSColor { Self.color(for: viewModel) }

    private var timestamp: String? {
        guard let lastUpdated = viewModel.lastUpdated, !viewModel.checkState.isChecking else { return nil }
        return Self.shortRelativeDescription(of: lastUpdated)
    }

    /// A compact "1s ago" / "4m ago" / "2h ago" — the crown only has room for a few characters
    /// beside the refresh button.
    private static func shortRelativeDescription(of date: Date) -> String {
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)

        if seconds < 60 { return "\(max(seconds, 1))s ago" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }

        return "\(minutes / 60)h ago"
    }
}

/// The refresh control, sitting inside the crown band rather than the footer. Spins while a check
/// is in flight.
private struct PopupCrownRefreshButton: View {
    let isChecking: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            PopupVectorIcon.refresh
                .fill(PopupLayout.Colors.crownLabel.swiftUI)
                .frame(
                    width: PopupLayout.Crown.refreshGlyphSize,
                    height: PopupLayout.Crown.refreshGlyphSize
                )
                .rotationEffect(.degrees(rotation))
                .frame(
                    width: PopupLayout.Crown.refreshButtonSize,
                    height: PopupLayout.Crown.refreshButtonSize
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: PopupLayout.Crown.refreshButtonCornerRadius,
                        style: .continuous
                    )
                    .fill(
                        (isHovering
                            ? PopupLayout.Colors.crownButtonBackgroundHover
                            : PopupLayout.Colors.crownButtonBackground).swiftUI
                    )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .onChange(of: isChecking) { updateSpin(isChecking: isChecking) }
        .onAppear { updateSpin(isChecking: isChecking) }
    }

    private func updateSpin(isChecking: Bool) {
        if isChecking {
            withAnimation(
                .linear(duration: PopupLayout.Crown.spinDuration).repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        } else {
            // Drop straight back to rest; letting it animate would spin backwards to zero.
            withAnimation(.linear(duration: 0)) { rotation = 0 }
        }
    }
}
