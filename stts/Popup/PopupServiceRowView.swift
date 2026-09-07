//
//  PopupServiceRowView.swift
//  stts
//

import SwiftUI

/// One service in the affected list: a favicon chip carrying a severity dot, the service's name and
/// the provider's message, then when it started and an arrow out to the status page.
///
/// This replaces the severity-railed cards of the previous iteration. Severity lives on the dot now,
/// and the legend above the list carries the colour key, so the row itself never has to explain what
/// its colour means.
struct PopupServiceRowView: View {
    let item: PopupViewModel.AffectedItem
    let onOpen: (URL) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: PopupLayout.ServiceRow.contentGap) {
            PopupFaviconChipWithDot(
                identifier: item.faviconIdentifier,
                faviconURL: item.faviconURL,
                initial: item.name.first.map(String.init) ?? "?",
                dotColor: item.dotColor
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(PopupLayout.Fonts.serviceName.swiftUI)
                    .foregroundColor(PopupLayout.Colors.serviceName.swiftUI)
                    .lineLimit(1)

                Text(item.message)
                    .font(PopupLayout.Fonts.serviceMessage.swiftUI)
                    .foregroundColor(PopupLayout.Colors.serviceMessage.swiftUI)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: PopupLayout.ServiceRow.contentGap)

            HStack(spacing: PopupLayout.ServiceRow.trailingGap) {
                // Only rendered when the provider actually reports a time — no fallback, no guess.
                if let timeLabel = item.timeLabel {
                    Text(timeLabel)
                        .font(PopupLayout.Fonts.serviceTime.swiftUI)
                        .foregroundColor(PopupLayout.Colors.serviceTime.swiftUI)
                }

                Text("↗")
                    .font(PopupLayout.Fonts.serviceArrow.swiftUI)
                    .foregroundColor(PopupLayout.Colors.serviceArrow.swiftUI)
            }
            .fixedSize()
        }
        .padding(PopupLayout.ServiceRow.padding)
        .background(isHovering ? PopupLayout.Colors.groupBackgroundHover.swiftUI : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onOpen(item.url) }
    }
}

/// A hairline between rows of a group, inset past the favicon chip so it aligns with the text.
struct PopupRowSeparator: View {
    var inset: CGFloat = PopupLayout.ServiceRow.separatorInset
    var color: NSColor = PopupLayout.Colors.rowSeparator

    var body: some View {
        color.swiftUI
            .frame(height: PopupLayout.hairlineWidth)
            .padding(.leading, inset)
    }
}

/// Wraps a set of rows in the design's inset grouped-list container.
struct PopupGroupBox<Content: View>: View {
    var topMargin: CGFloat = PopupLayout.Group.topMargin
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PopupLayout.Colors.groupBackground.swiftUI)
        .clipShape(RoundedRectangle(cornerRadius: PopupLayout.Group.cornerRadius, style: .continuous))
        .padding(.horizontal, PopupLayout.Group.horizontalMargin)
        .padding(.top, topMargin)
    }
}
