//
//  NSAppearance+Extensions.swift
//  PreferencesWindow
//

import Cocoa

extension NSAppearance {
    var isDarkMode: Bool {
        name == .darkAqua || name == .vibrantDark
    }
}
