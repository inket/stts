//
//  PreferencesLayout.swift
//  stts
//

import SwiftUI

/// The handful of values the settings window still has to state for itself — everything else
/// (control shapes, focus, accessibility) comes from stock SwiftUI/`Form`.
enum PreferencesLayout {
    static let windowSize = CGSize(width: 760, height: 560)
    static let minWindowSize = CGSize(width: 700, height: 480)

    static let sidebarWidth: CGFloat = 220
    static let isSidebarResizable = false
    static let sidebarWidthRange: ClosedRange<CGFloat> = 200...260

    /// Used for content that means stts (the Monitoring glyph, "Every change") — window chrome
    /// follows the user's own system accent.
    static let accent = Color(nsColor: NSColor(designHex: 0x2F7D4F))
}
