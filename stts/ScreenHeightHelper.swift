//
//  ScreenHeightHelper.swift
//  stts
//
import Cocoa

/// DisplaySizeHelper - checks in-flight active display size
/// and offers proper height to the consumers
class ScreenHeightHelper {
    /// custom margin to be deducted from the computed screen rect (but not affecting defaultMaxHeight)
    let verticalMargin: CGFloat
    /// computed maximum available value for the given screen (please, use .update() when appropriate)
    private(set) var currentMaxHeight: CGFloat
    /// vertical margin used alway, initial max height used on init, and as long as NSScreen not available
    init(verticalMargin: CGFloat, initialMaxHeight: CGFloat) {
        self.verticalMargin = verticalMargin
        self.currentMaxHeight = initialMaxHeight
    }

    /// updates max height by capturing current screen (where the mouse is)
    func update() {
        // Get the current mouse location in global coordinates and find screen containing it
        let mouseLocation = NSEvent.mouseLocation
        // yep, it can happen mac has no screen (just like it can have multiple screens)
        let currentScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
        // lastly, using .visibleFrame to respect Dock, and system status bar height (it's always horisontal)
        if let rect = currentScreen?.visibleFrame {
            let statusBarHeight = NSStatusBar.system.thickness
            currentMaxHeight = rect.height - statusBarHeight - verticalMargin
        }
        // no sense to use else clause and set current to default, just keep what it was
    }
}
