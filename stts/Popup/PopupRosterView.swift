//
//  PopupRosterView.swift
//  stts
//

import SwiftUI

struct PopupRosterView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onOpen: (URL) -> Void

    @State private var isHoveringHeader = false

    var body: some View {
        PopupGroupBox(topMargin: topMargin) {
            header

            if viewModel.rosterExpanded {
                PopupLayout.Colors.hairline.swiftUI
                    .frame(height: PopupLayout.hairlineWidth)

                rosterRows
            }
        }
    }

    /// Sits tight under the affected group when there is one. When it's the only group in the
    /// panel, it has no top margin of its own — the scroll region's own content margin covers that
    /// gap instead (see `PopupContentView.scrollingMiddle`).
    private var topMargin: CGFloat {
        viewModel.affected.isEmpty ? 0 : PopupLayout.Group.spacing
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: PopupLayout.RosterStack.contentGap) {
            if viewModel.rosterExpanded {
                // The stack collapses to a single dot once the list below is doing the work of
                // showing which services these are.
                Circle()
                    .fill(PopupLayout.Colors.dotOperational.swiftUI)
                    .frame(
                        width: PopupLayout.RosterStack.expandedDotSize,
                        height: PopupLayout.RosterStack.expandedDotSize
                    )
                    .frame(width: PopupLayout.ServiceRow.chipSize)
            } else {
                chipStack
            }

            Text(countLabel)
                .font(
                    (viewModel.rosterExpanded
                        ? PopupLayout.Fonts.rosterCountExpanded
                        : PopupLayout.Fonts.rosterCount).swiftUI
                )
                .foregroundColor(PopupLayout.Colors.rosterCount.swiftUI)

            Spacer(minLength: 0)

            Text(viewModel.rosterExpanded ? "⌄" : "›")
                .font(PopupLayout.Fonts.rosterChevron.swiftUI)
                .foregroundColor(
                    (viewModel.rosterExpanded
                        ? PopupLayout.Colors.rosterChevronExpanded
                        : PopupLayout.Colors.rosterChevron).swiftUI
                )
        }
        .padding(PopupLayout.RosterStack.padding)
        .background(headerBackground)
        .contentShape(Rectangle())
        .onHover { isHoveringHeader = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.rosterExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isHoveringHeader {
            PopupLayout.Colors.groupBackgroundHover.swiftUI
        } else if viewModel.rosterExpanded {
            PopupLayout.Colors.groupHeaderBackground.swiftUI
        } else {
            Color.clear
        }
    }

    /// Up to four chips, each sliding back over its predecessor with a ring in the composited panel
    /// colour so the overlap reads cleanly. The count carries however many aren't shown.
    private var chipStack: some View {
        HStack(spacing: -PopupLayout.RosterStack.overlap) {
            ForEach(viewModel.roster.prefix(PopupLayout.RosterStack.maxChips)) { item in
                PopupFaviconChip(
                    identifier: item.faviconIdentifier,
                    faviconURL: item.faviconURL,
                    initial: item.name.first.map(String.init) ?? "?",
                    chipSize: PopupLayout.RosterStack.chipSize,
                    cornerRadius: PopupLayout.RosterStack.chipCornerRadius,
                    faviconSize: PopupLayout.RosterStack.faviconSize
                )
                // The ring sits *outside* the chip, so the chip keeps its full 22pt and the ring
                // reads as a gap punched in whichever chip it overlaps.
                .background(
                    RoundedRectangle(
                        cornerRadius: PopupLayout.RosterStack.chipCornerRadius
                            + PopupLayout.RosterStack.ringWidth,
                        style: .continuous
                    )
                    .fill(PopupLayout.Colors.chipRing.swiftUI)
                    .padding(-PopupLayout.RosterStack.ringWidth)
                )
            }
        }
        .fixedSize()
    }

    private var countLabel: String {
        let count = viewModel.operationalCount
        return count == 1 ? "1 operational" : "\(count) operational"
    }

    // MARK: - Expanded rows

    /// Rows lay out in full; the popup's single scroll region takes the overflow rather than nesting
    /// a second scroll view here, which would have no ideal height of its own and collapse.
    private var rosterRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.roster.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    PopupRowSeparator()
                }

                PopupRosterRowView(item: item, onOpen: onOpen)
            }
        }
    }
}

/// One operational service: chip, name, and an arrow out to its status page. One line, no subtitle —
/// the only affordance is opening the page, so clicking a row leaves the popup.
private struct PopupRosterRowView: View {
    let item: PopupViewModel.RosterItem
    let onOpen: (URL) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: PopupLayout.RosterRow.contentGap) {
            PopupFaviconChip(
                identifier: item.faviconIdentifier,
                faviconURL: item.faviconURL,
                initial: item.name.first.map(String.init) ?? "?",
                chipSize: PopupLayout.RosterRow.chipSize,
                cornerRadius: PopupLayout.RosterRow.chipCornerRadius,
                faviconSize: PopupLayout.RosterRow.faviconSize
            )
            .padding(.leading, PopupLayout.RosterRow.chipLeadingInset)

            Text(item.name)
                .font(PopupLayout.Fonts.rosterRowName.swiftUI)
                .foregroundColor(PopupLayout.Colors.rosterRowName.swiftUI)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if PopupLayout.ServiceRow.showsLinkArrow {
                Text("↗")
                    .font(PopupLayout.Fonts.serviceArrow.swiftUI)
                    .foregroundColor(PopupLayout.Colors.rosterRowArrow.swiftUI)
                    .fixedSize()
            }
        }
        .padding(.horizontal, PopupLayout.RosterRow.horizontalPadding)
        .frame(height: PopupLayout.RosterRow.height)
        .background(isHovering ? PopupLayout.Colors.rosterRowHover.swiftUI : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onOpen(item.url) }
    }
}
