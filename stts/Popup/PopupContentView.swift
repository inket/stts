//
//  PopupContentView.swift
//  stts
//

import SwiftUI

/// Root of the popup's SwiftUI hierarchy: a pinned header, a scrolling middle section, and a pinned
/// footer.
///
/// The panel is sized by AppKit (`MBPopupController.resizePopup`), not by this view's intrinsic
/// size, so the view reports how tall it *would like* to be through `onContentHeightChange`;
/// `PopupViewController` clamps that to `PopupLayout.maxHeight` and resizes the panel. Everything
/// above that ceiling is absorbed by the middle section's scroll view.
///
/// Every section — including the footer — contributes its *real, measured* height to that report,
/// never a hand-computed estimate. An estimate for the footer used to live here (its padding plus
/// `NSFont.boundingRectForFont`, which measures a font's worst-case glyph bounds, not the line
/// height SwiftUI actually lays text out at) and ran consistently taller than the real view. AppKit
/// sized the panel to the inflated total, and the `VStack` handed the leftover to the scroll view —
/// so whenever the content was shorter than the max height, the scroll region always had dead space
/// at its bottom that didn't belong to any row, reading as an affordance for content that wasn't
/// there.
///
/// The background is the panel colour at 84%/86% — an `NSVisualEffectView` sits behind the hosting
/// view (see `PopupViewController.setup()`), so the desktop tints through.
struct PopupContentView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onOpenSettings: () -> Void
    let onRefresh: () -> Void
    let onOpen: (URL) -> Void
    let onContentHeightChange: (CGFloat) -> Void

    /// The live popup scrolls its middle section against a fixed panel height. Snapshot rendering
    /// turns this off so the view sizes to its natural height instead (a `ScrollView` has no ideal
    /// height of its own, so it would otherwise collapse or fill arbitrarily).
    var scrollsContent = true

    /// Snapshot rendering has no vibrancy view behind it, so it paints the panel colour opaque
    /// instead — otherwise every snapshot would come out semi-transparent over nothing.
    var opaqueBackground = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasNoSelectedServices {
                PopupEmptyStateView(onOpenSettings: onOpenSettings)
                    .measuringPopupHeight()
            } else {
                PopupHeaderView(viewModel: viewModel, onRefresh: onRefresh)
                    .measuringPopupHeight()

                if scrollsContent {
                    scrollingMiddle
                } else {
                    middle.measuringPopupHeight()
                }
            }

            PopupBottomBarView(onOpenSettings: onOpenSettings)
                .padding(.top, PopupLayout.Footer.topMargin)
                .measuringPopupHeight()
        }
        .frame(width: PopupLayout.contentWidth)
        .background(background)
        // The panel fill behind this view is the arrow's colour, not the panel's, so the design's
        // hairline has to be drawn here rather than left to MBPopup's content inset.
        .overlay(
            RoundedRectangle(cornerRadius: PopupLayout.cornerRadius, style: .continuous)
                .strokeBorder(
                    PopupLayout.Colors.panelBorder.swiftUI,
                    lineWidth: PopupLayout.panelBorderWidth
                )
        )
        .onPreferenceChange(PopupSectionHeightKey.self) { totalHeight in
            onContentHeightChange(totalHeight)
        }
    }

    /// Expanding the roster can push it below the fold when the panel is already at its ceiling, so
    /// the disclosure row is scrolled to the top as it opens — otherwise the services it just
    /// revealed are off-screen and the click looks like it did nothing.
    private var scrollingMiddle: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                middle.measuringPopupHeight()
            }
            .onChange(of: viewModel.rosterExpanded) { isExpanded in
                guard isExpanded else { return }

                // A frame late, so the panel has taken its new height first and the scroll view
                // knows how much room it actually has to work with.
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(Self.rosterAnchor, anchor: .top)
                    }
                }
            }
        }
    }

    /// Scroll target for the roster's disclosure row.
    fileprivate static let rosterAnchor = "roster"

    @ViewBuilder
    private var background: some View {
        if opaqueBackground {
            PopupLayout.Colors.panelSolid.swiftUI
        } else {
            PopupLayout.Colors.panelTint.swiftUI
        }
    }

    // MARK: - Middle

    /// The affected services in one inset group, then the operational roster in another.
    private var middle: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.affected.isEmpty {
                PopupGroupBox {
                    ForEach(Array(viewModel.affected.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            PopupRowSeparator()
                        }

                        PopupServiceRowView(item: item, onOpen: onOpen)
                    }
                }
            }

            if !viewModel.roster.isEmpty {
                PopupRosterView(viewModel: viewModel, onOpen: onOpen)
                    .opacity(viewModel.checkState.isChecking ? 0.5 : 1)
                    .id(Self.rosterAnchor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Height reporting

/// Summed heights of the popup's self-measuring sections: header, scrollable middle, and footer.
private struct PopupSectionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension View {
    /// Contributes this view's laid-out height to the popup's total content height.
    ///
    /// Applied inside a scroll view, this reports the content's *ideal* height rather than the
    /// visible height, which is exactly what the panel needs in order to decide whether it has to
    /// clamp and start scrolling.
    func measuringPopupHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PopupSectionHeightKey.self, value: proxy.size.height)
            }
        )
    }
}
