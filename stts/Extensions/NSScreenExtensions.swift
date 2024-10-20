//
//  NSScreenExtensions.swift
//  stts
//

import Cocoa

extension NSScreen {
    static var usableHeightOfActiveScreen: CGFloat? {
        // Active screen is the screen that has the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first {
            // Big gotcha here, CGRect.contains(point) returns false when x or y is at maxX/maxY.
            // For a menu bar button, it's common for the user to click at the upper edge of the screen, for which
            // CGRect.contains(mouseLocation) would be false. Test this using our own method instead.
            ($0.frame.minX...$0.frame.maxX).contains(mouseLocation.x) &&
            ($0.frame.minY...$0.frame.maxY).contains(mouseLocation.y)
        }

        if let currentScreen {
            let statusBarHeight = NSStatusBar.system.thickness
            return currentScreen.visibleFrame.height - statusBarHeight
        } else {
            return nil
        }
    }
}
