//
//  StatusColor.swift
//  stts
//

import Cocoa

/// Status colours, shared by the popup, the menu bar tick, and the services editor. Declared in
/// sRGB explicitly rather than via `NSColor.orange` etc., which resolve in a different colour space
/// and produce visibly different hues.
enum StatusColor {
    static let green = NSColor(srgbRed: 0.36, green: 0.68, blue: 0.46, alpha: 1)
    static let blue = NSColor(srgbRed: 0.24, green: 0.54, blue: 1, alpha: 0.8)
    static let orange = NSColor(srgbRed: 1, green: 0.584, blue: 0, alpha: 1)
    static let red = NSColor(srgbRed: 0.9, green: 0.4, blue: 0.23, alpha: 1)
    static let gray = NSColor.tertiaryLabelColor
}
