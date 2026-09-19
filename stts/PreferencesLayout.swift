//
//  PreferencesLayout.swift
//  stts
//

import SwiftUI

/// The handful of values the settings window still has to state for itself.
///
/// It used to be the full counterpart to `PopupLayout` — every colour, font and metric transcribed
/// from the "stts Settings" design doc, because every control in the window was hand-drawn. The
/// window is stock SwiftUI now (`NavigationSplitView`, `Form`, `Toggle`, `Picker`), so the system
/// supplies all of that, and what's left here is only what no system default can know: the window's
/// size and sidebar width, and the app's accent colour.
///
/// That's a deliberate trade against the design doc, made with the user: looking and behaving like
/// a macOS settings window — keyboard focus, accessibility, Increase Contrast, the system accent —
/// is worth more than matching the mockup's exact palette and control shapes. `PopupLayout` still
/// carries the full spec for the popup, which is a bespoke panel and genuinely needs one.
enum PreferencesLayout {
    static let windowSize = CGSize(width: 760, height: 560)
    static let minWindowSize = CGSize(width: 700, height: 480)

    /// The pane sidebar's width. Fixed by default — there's nothing in four short rows worth
    /// resizing for; flip `isSidebarResizable` and the column drags between the min and max.
    static let sidebarWidth: CGFloat = 220
    static let isSidebarResizable = false
    static let sidebarWidthRange: ClosedRange<CGFloat> = 200...260

    /// The app's green — the same value the popup's operational green is drawn from. Used for
    /// content that means stts (the Monitoring glyph, the "Every change" label), not for the
    /// window's chrome: controls, focus rings and the sidebar selection pills follow the user's own
    /// system accent, the way any other settings window does.
    static let accent = Color(nsColor: NSColor(designHex: 0x2F7D4F))
}
