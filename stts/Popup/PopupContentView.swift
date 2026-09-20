//
//  PopupContentView.swift
//  stts
//

import SwiftUI

/// The panel is sized by AppKit (`MBPopupController.resizePopup`), not by this view's intrinsic
/// size, so the view reports how tall it *would like* to be through `onContentHeightChange`;
/// `PopupViewController` clamps that to `PopupLayout.maxHeight` and resizes the panel. Everything
/// above that ceiling is absorbed by the middle section's scroll view.
///
/// Every section, footer included, contributes its *real, measured* height to that report rather
/// than a hand-computed estimate — a font-metrics-based estimate for the footer used to run
/// consistently taller than the real view, leaving dead space at the bottom of the scroll region.
///
/// The background is the panel colour at 84%/86%; an `NSVisualEffectView` behind the hosting view
/// (see `PopupViewController.setup()`) is what lets the desktop tint through.
struct PopupContentView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onOpenSettings: () -> Void
    let onRefresh: () -> Void
    let onOpen: (URL) -> Void
    let onContentHeightChange: (CGFloat) -> Void

    /// Off for snapshot rendering, so the view sizes to its natural height instead of a `ScrollView`
    /// with no ideal height of its own.
    var scrollsContent = true

    /// Snapshot rendering has no vibrancy view behind it, so this paints the panel colour opaque.
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
                    // No ScrollView here to carry the top margin via content insets, so add it as padding.
                    middle
                        .padding(.top, PopupLayout.Group.topMargin)
                        .measuringPopupHeight()
                }
            }

            PopupBottomBarView(
                onOpenSettings: onOpenSettings,
                showsSettings: !viewModel.hasNoSelectedServices
            )
            .measuringPopupHeight()
        }
        .frame(width: PopupLayout.contentWidth)
        .background(background)
        // The fill behind this view is the arrow's colour, not the panel's, so the border has to be
        // drawn here rather than left to MBPopup's content inset.
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
    /// the disclosure row is scrolled to the top as it opens.
    private var scrollingMiddle: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                middle
                    .measuringPopupHeight()
            }
            .contentMargins(.top, PopupLayout.Group.topMargin, for: .scrollContent)
            .contentMargins(.bottom, PopupLayout.Group.bottomMargin, for: .scrollContent)
            // contentMargins insets the viewport without adding to middle's own measured size, so
            // report it separately or the panel sizes itself short by that amount.
            .contributingFixedHeight(PopupLayout.Group.topMargin)
            .contributingFixedHeight(PopupLayout.Group.bottomMargin)
            .onChange(of: viewModel.rosterExpanded) {
                guard viewModel.rosterExpanded else { return }

                // A frame late, so the panel has already taken its new height.
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
                // Top margin comes from the scroll view's content margin instead (see `body` when not scrolling).
                PopupGroupBox(topMargin: 0) {
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
    /// Contributes this view's laid-out height to the popup's total content height. Inside a scroll
    /// view, this reports the content's ideal height rather than the visible height.
    func measuringPopupHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PopupSectionHeightKey.self, value: proxy.size.height)
            }
        )
    }

    /// Contributes a known, fixed amount to the popup's total content height, for space no view's
    /// own measured size includes (e.g. a `ScrollView`'s content margin — see `scrollingMiddle`).
    func contributingFixedHeight(_ height: CGFloat) -> some View {
        background(Color.clear.preference(key: PopupSectionHeightKey.self, value: height))
    }
}
