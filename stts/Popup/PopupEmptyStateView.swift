//
//  PopupEmptyStateView.swift
//  stts
//

import SwiftUI

struct PopupEmptyStateView: View {
    let onSelectServices: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            EmptyStateIllustration(kind: .addServices)

            Text("No services yet")
                .font(PopupLayout.Fonts.emptyStateTitle.swiftUI)
                .foregroundColor(PopupLayout.Colors.emptyStateTitle.swiftUI)
                .padding(.top, PopupLayout.EmptyState.titleMarginTop)

            Text("Pick the services you want stts to monitor and their status will show up here.")
                .font(PopupLayout.Fonts.emptyStateSubtitle.swiftUI)
                .foregroundColor(PopupLayout.Colors.emptyStateSubtitle.swiftUI)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, PopupLayout.EmptyState.subtitleMarginTop)

            Button(action: onSelectServices) {
                Text("Choose services…")
                    .font(PopupLayout.Fonts.emptyStateButton.swiftUI)
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
