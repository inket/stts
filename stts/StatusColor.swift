//
//  StatusColor.swift
//  stts
//

import Cocoa

/// Status colours, shared by the popup, the menu bar tick, and the services editor.
///
/// Declared in sRGB to match the hex values the "stts Popup Final" design specifies
/// (`#5CAD75` / `#FF9500` / `#E6663B`). The green and red component values are unchanged from the
/// pre-redesign colours — only the colour space is now stated explicitly, so what ships matches
/// what was mocked up. Orange did change: it was `NSColor.orange` (`#FF8000`), which is a visibly
/// different hue from the specified `#FF9500`.
enum StatusColor {
    static let green = NSColor(srgbRed: 0.36, green: 0.68, blue: 0.46, alpha: 1)
    static let blue = NSColor(srgbRed: 0.24, green: 0.54, blue: 1, alpha: 0.8)
    static let orange = NSColor(srgbRed: 1, green: 0.584, blue: 0, alpha: 1)
    static let red = NSColor(srgbRed: 0.9, green: 0.4, blue: 0.23, alpha: 1)
    static let gray = NSColor.tertiaryLabelColor
}
