//
//  PopupBottomBarView.swift
//  stts
//

import SwiftUI

/// Pinned footer: the wordmark and Settings.
struct PopupBottomBarView: View {
    let onOpenSettings: () -> Void

    @State private var isHoveringSettings = false

    var body: some View {
        HStack(spacing: 0) {
            Text("stts")
                .font(PopupLayout.Fonts.footerWordmark.swiftUI)
                .tracking(PopupLayout.Fonts.footerWordmarkKerning)
                .foregroundColor(PopupLayout.Colors.footerWordmark.swiftUI)

            Spacer(minLength: 0)

            Button(action: onOpenSettings) {
                Text("Settings…")
                    .font(PopupLayout.Fonts.footerAction.swiftUI)
                    .foregroundColor(
                        (isHoveringSettings
                            ? PopupLayout.Colors.footerActionHover
                            : PopupLayout.Colors.footerAction).swiftUI
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHoveringSettings = $0 }
        }
        .padding(PopupLayout.Footer.padding)
        .overlay(alignment: .top) {
            PopupLayout.Colors.hairline.swiftUI.frame(height: PopupLayout.hairlineWidth)
        }
    }
}
