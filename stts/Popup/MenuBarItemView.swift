//
//  MenuBarItemView.swift
//  stts
//

import Cocoa

/// The menu bar item: the "stts" wordmark with a thin coloured tick beneath it carrying the overall
/// status.
///
/// Deliberately AppKit rather than SwiftUI. It draws into an `NSStatusItem`'s button, needs to pass
/// clicks straight through to that button (which is what MBPopup's event monitors watch for), and
/// has to resolve its colours against the *menu bar's* appearance rather than the app's — all of
/// which are simpler to get right with a plain `NSView` than with a hosted SwiftUI view.
///
/// Sized to fit the existing 30pt status item slot, so `statusItem.length` is unchanged.
final class MenuBarItemView: NSView {
    var status: ServiceStatus = .good {
        didSet {
            guard status != oldValue else { return }
            needsDisplay = true
        }
    }

    var isChecking: Bool = false {
        didSet {
            guard isChecking != oldValue else { return }
            // Dimming the whole view rather than each colour: `withAlphaComponent` *replaces* a
            // colour's alpha, which would flatten the deliberately translucent unknown-grey tick
            // into solid white.
            alphaValue = isChecking ? PopupLayout.MenuBarItem.checkingOpacity : 1
        }
    }

    /// Clicks belong to the status item button underneath — this view is purely decorative.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let wordmark = NSAttributedString(
            string: "stts",
            attributes: [
                .font: PopupLayout.Fonts.menuBarItem,
                .foregroundColor: NSColor.labelColor
            ]
        )

        let wordmarkSize = wordmark.size()
        let tickHeight = PopupLayout.MenuBarItem.tickHeight
        let gap = PopupLayout.MenuBarItem.wordmarkTickGap
        let groupHeight = wordmarkSize.height + gap + tickHeight

        // Centre the wordmark-plus-tick group as a unit, so the wordmark doesn't sit visually low
        // once the tick is added beneath it.
        let groupBottom = (bounds.height - groupHeight) / 2

        wordmark.draw(
            at: NSPoint(
                x: (bounds.width - wordmarkSize.width) / 2,
                y: groupBottom + tickHeight + gap
            )
        )

        let tickRect = NSRect(
            x: (bounds.width - PopupLayout.MenuBarItem.tickWidth) / 2,
            y: groupBottom,
            width: PopupLayout.MenuBarItem.tickWidth,
            height: tickHeight
        )

        tickColor.setFill()
        NSBezierPath(
            roundedRect: tickRect,
            xRadius: PopupLayout.MenuBarItem.tickCornerRadius,
            yRadius: PopupLayout.MenuBarItem.tickCornerRadius
        ).fill()
    }

    private var tickColor: NSColor {
        switch status {
        case .major:
            return PopupLayout.Colors.menuBarMajor
        case .minor:
            return PopupLayout.Colors.menuBarMinor
        case .maintenance:
            return PopupLayout.Colors.menuBarMaintenance
        case .undetermined:
            return PopupLayout.Colors.menuBarUnknown
        case .good, .notice:
            return PopupLayout.Colors.menuBarOperational
        }
    }
}
