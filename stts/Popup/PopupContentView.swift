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
                    ScrollView(.vertical) {
                        middle.measuringPopupHeight()
                    }
                } else {
                    middle.measuringPopupHeight()
                }
            }

            PopupBottomBarView(onOpenSettings: onOpenSettings)
                .padding(.top, PopupLayout.Footer.topMargin)
        }
        .frame(width: PopupLayout.contentWidth)
        .background(background)
        .onPreferenceChange(PopupSectionHeightKey.self) { sectionsHeight in
            onContentHeightChange(sectionsHeight + footerHeight)
        }
    }

    @ViewBuilder
    private var background: some View {
        if opaqueBackground {
            PopupLayout.Colors.panelSolid.swiftUI
        } else {
            PopupLayout.Colors.panelTint.swiftUI
        }
    }

    /// The footer isn't measured (it's a fixed row) — its height is its own padding plus the line
    /// of text, plus the margin separating it from the last group.
    private var footerHeight: CGFloat {
        PopupLayout.Footer.topMargin
            + PopupLayout.Footer.padding.top
            + PopupLayout.Footer.padding.bottom
            + PopupLayout.Fonts.footerAction.boundingRectForFont.height
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Height reporting

/// Summed heights of the popup's self-measuring sections (header + scrollable middle). The pinned
/// footer is a fixed row and isn't measured.
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
