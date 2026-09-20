//
//  PopupEmptyStateView.swift
//  stts
//

import SwiftUI

struct PopupEmptyStateView: View {
    let onOpenSettings: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            Text("No services selected")
                .font(PopupLayout.Fonts.emptyStateTitle.swiftUI)
                .foregroundColor(PopupLayout.Colors.emptyStateTitle.swiftUI)

            Text("Pick the ones you care about in Settings")
                .font(PopupLayout.Fonts.emptyStateSubtitle.swiftUI)
                .foregroundColor(PopupLayout.Colors.emptyStateSubtitle.swiftUI)
                .padding(.top, PopupLayout.EmptyState.subtitleMarginTop)

            Button(action: onOpenSettings) {
                HStack(spacing: PopupLayout.EmptyState.buttonGap) {
                    Image(systemName: "gearshape")
                        .font(.system(size: PopupLayout.EmptyState.buttonGlyphSize * 0.8))

                    Text("Open Settings")
                        .font(PopupLayout.Fonts.emptyStateButton.swiftUI)
                }
                .foregroundColor(PopupLayout.Colors.emptyStateTitle.swiftUI)
                .padding(PopupLayout.EmptyState.buttonPadding)
                .background(
                    RoundedRectangle(
                        cornerRadius: PopupLayout.EmptyState.buttonCornerRadius,
                        style: .continuous
                    )
                    .fill(
                        (isHovering
                            ? PopupLayout.Colors.emptyStateButtonBackgroundHover
                            : PopupLayout.Colors.emptyStateButtonBackground).swiftUI
                    )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .padding(.top, PopupLayout.EmptyState.buttonMarginTop)
        }
        .frame(maxWidth: .infinity)
        .padding(PopupLayout.EmptyState.padding)
    }
}
