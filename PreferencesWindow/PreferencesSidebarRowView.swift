//
//  PreferencesSidebarRowView.swift
//  PreferencesWindow
//

import Cocoa

@objc
class PreferencesSidebarRowView: NSTableRowView {
    static let identifier = NSUserInterfaceItemIdentifier(String(describing: PreferencesSidebarRowView.self))
    static let height: CGFloat = 36

    override var isEmphasized: Bool {
        get {
            window?.isKeyWindow == true
        }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        let selectionRect = bounds.insetBy(dx: 10, dy: 0)

        if isEmphasized {
            if effectiveAppearance.isDarkMode {
                NSColor(calibratedRed: 54 / 255, green: 81 / 255, blue: 85 / 255, alpha: 1).setFill()
            } else {
                NSColor(calibratedRed: 45 / 255, green: 71 / 255, blue: 75 / 255, alpha: 1).setFill()
            }

            if effectiveAppearance.isDarkMode {
                NSColor(calibratedRed: 56 / 255, green: 59 / 255, blue: 96 / 255, alpha: 1).setFill()
            } else {
                NSColor(calibratedRed: 47 / 255, green: 51 / 255, blue: 89 / 255, alpha: 1).setFill()
            }
        } else {
            if effectiveAppearance.isDarkMode {
                NSColor(calibratedRed: 62 / 255, green: 62 / 255, blue: 62 / 255, alpha: 1).setFill()
            } else {
                NSColor(calibratedRed: 216 / 255, green: 216 / 255, blue: 216 / 255, alpha: 1).setFill()
            }
        }

        let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        selectionPath.fill()
    }
}
