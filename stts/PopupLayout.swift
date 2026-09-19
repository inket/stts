//
//  PopupLayout.swift
//  stts
//

import SwiftUI

/// Single source of truth for the popup's geometry, typography, and colour constants, as specified
/// in the "stts Popup Native" design doc. Views read from here instead of hardcoding their own
/// values, so the whole popup stays in sync with one spec.
///
/// "Native" is the third iteration. It keeps Crown's palette verbatim (the design says so
/// explicitly) but rebuilds the structure around macOS conventions: a vibrancy panel, SF metrics,
/// hairline separators, and inset grouped lists instead of severity-railed cards. Severity moved
/// off the row and onto a corner dot on each service's favicon chip.
///
/// It doesn't cover every popup state — "no connection", "no services selected", a mid-check
/// progress bar, and the menu bar tick aren't in that doc. Those keep their existing copy/layout
/// and inherit this file's geometry and colour tokens. See `Scripts/popup_redesign_plan.md`.
///
/// Values are declared in AppKit types (`NSColor`/`NSFont`) because a few consumers are necessarily
/// AppKit — the popup panel's vibrancy backing and the menu bar item's tick are drawn outside any
/// SwiftUI hierarchy. SwiftUI views use the `.swiftUI` bridges at the bottom of this file.
enum PopupLayout {
    static let contentWidth: CGFloat = 340
    static let cornerRadius: CGFloat = 12

    /// Hard ceiling on popup height. Content taller than this scrolls internally rather than
    /// growing the panel.
    static let maxHeight: CGFloat = 490

    /// The little triangle joining the panel to the menu bar item. Tinted with the crown's colour
    /// rather than the panel's, so the band reads as continuing up into the menu bar.
    static let arrowSize = CGSize(width: 15, height: 8)

    /// Hairline around the whole panel — 0.5pt, which at 2× is a single device pixel.
    static let panelBorderWidth: CGFloat = 0.5

    /// Standard separator weight throughout the panel.
    static let hairlineWidth: CGFloat = 0.5

    /// The colour band at the top of the popup: a count, what it's a count *of*, when it was last
    /// checked, and a refresh button. Sized like a native header rather than a poster.
    enum Crown {
        static let padding = EdgeInsets(top: 13, leading: 14, bottom: 12, trailing: 14)
        static let allClearPadding = EdgeInsets(top: 15, leading: 14, bottom: 14, trailing: 14)
        static let contentGap: CGFloat = 11
        static let trailingGap: CGFloat = 8
        static let allClearSubtitleTopMargin: CGFloat = 3

        static let refreshButtonSize: CGFloat = 22
        static let refreshButtonCornerRadius: CGFloat = 6
        static let refreshGlyphSize: CGFloat = 12
        /// One full rotation of the refresh glyph while a check is in flight.
        static let spinDuration: TimeInterval = 1
    }

    enum StatusBar {
        static let height: CGFloat = 3
        static let segmentGap: CGFloat = 1
    }

    enum Legend {
        static let swatchSize: CGFloat = 6
        static let swatchCornerRadius: CGFloat = 2
        static let swatchGap: CGFloat = 6
        static let itemsGap: CGFloat = 13
        static let padding = EdgeInsets(top: 10, leading: 14, bottom: 11, trailing: 14)
    }

    /// An inset grouped list, the way a native macOS sidebar or Settings pane groups rows.
    enum Group {
        static let cornerRadius: CGFloat = 10
        static let horizontalMargin: CGFloat = 12
        /// Gap above the first group, below the legend hairline.
        static let topMargin: CGFloat = 12
        /// Gap under the last group
        static let bottomMargin: CGFloat = 12
        /// Gap between stacked groups (affected list → operational roster).
        static let spacing: CGFloat = 8
    }

    /// A service in the affected list: favicon chip with a severity dot, then name and message
    /// across the rest of the row.
    enum ServiceRow {
        static let padding = EdgeInsets(top: 8, leading: 11, bottom: 8, trailing: 11)
        static let contentGap: CGFloat = 11

        static let chipSize: CGFloat = 24
        static let chipCornerRadius: CGFloat = 6
        static let faviconSize: CGFloat = 18

        /// The provider's message wraps rather than truncating at one line, but is capped so a single
        /// verbose incident can't push every other service out of the popup.
        static let messageLineLimit = 3

        /// The "↗" at the trailing edge of every row (both the affected list and the roster).
        /// Currently off: the whole row is already a link, and dropping it gives the message the
        /// full width. Flip to `true` to bring it back everywhere.
        static let showsLinkArrow = false

        static let dotSize: CGFloat = 8
        static let dotRingWidth: CGFloat = 1.5
        /// How far the dot hangs off the chip's bottom-trailing corner.
        static let dotOffset: CGFloat = 2

        /// Separators are inset past the chip: row padding + chip + gap.
        static let separatorInset: CGFloat = 46
    }

    /// The collapsed operational row: an overlapping stack of favicon chips, a count, a chevron.
    enum RosterStack {
        static let padding = EdgeInsets(top: 9, leading: 11, bottom: 9, trailing: 11)
        static let contentGap: CGFloat = 11

        static let chipSize: CGFloat = 22
        static let chipCornerRadius: CGFloat = 6
        static let faviconSize: CGFloat = 16
        static let ringWidth: CGFloat = 2
        /// Each chip after the first slides back over its predecessor, leaving 18pt exposed.
        static let overlap: CGFloat = 4
        /// The count carries however many services the stack doesn't show.
        static let maxChips = 4

        /// Green dot that replaces the chip stack once the group is expanded.
        static let expandedDotSize: CGFloat = 8
    }

    /// A single operational service, once the roster is expanded.
    enum RosterRow {
        static let height: CGFloat = 26
        static let horizontalPadding: CGFloat = 11
        static let contentGap: CGFloat = 11

        static let chipSize: CGFloat = 20
        static let chipCornerRadius: CGFloat = 5
        static let chipLeadingInset: CGFloat = 2
        static let faviconSize: CGFloat = 14

        /// Past this many rows the group scrolls instead of growing the panel.
        static let visibleRowLimit = 9
    }

    enum Footer {
        static let padding = EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
        /// Gap between the last group and the footer's hairline.
        static let topMargin: CGFloat = 13
    }

    enum EmptyState {
        static let padding = EdgeInsets(top: 26, leading: 14, bottom: 24, trailing: 14)
        static let subtitleMarginTop: CGFloat = 6
        static let buttonMarginTop: CGFloat = 14
        static let buttonPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        static let buttonCornerRadius: CGFloat = 6
        static let buttonGlyphSize: CGFloat = 14
        static let buttonGap: CGFloat = 7
    }

    enum MenuBarItem {
        /// Fits inside the existing 30pt `statusItem.length`, so the slot width is unchanged. Not a
        /// Native concern — this draws against the system menu bar, not the popup panel.
        static let tickWidth: CGFloat = 18
        static let tickHeight: CGFloat = 2
        static let tickCornerRadius: CGFloat = 1
        static let wordmarkTickGap: CGFloat = 2.5
        static let checkingOpacity: CGFloat = 0.45
    }

    // MARK: - Typography
    //
    // Back to the system font. Native's whole premise is SF metrics — the previous iteration's
    // bundled Inter was removed along with it.

    enum Fonts {
        static let crownNumber = NSFont.systemFont(ofSize: 34, weight: .semibold)
        /// −0.03em at 34pt.
        static let crownNumberKerning: CGFloat = -1.02

        static let crownTitle = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let crownSubtitle = NSFont.systemFont(ofSize: 11)
        static let crownTimestamp = NSFont.systemFont(ofSize: 11)

        static let allClearHeadline = NSFont.systemFont(ofSize: 15, weight: .semibold)
        /// −0.01em at 15pt.
        static let allClearHeadlineKerning: CGFloat = -0.15
        static let allClearSubtitle = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        /// .08em at 10.5pt.
        static let allClearSubtitleKerning: CGFloat = 0.84

        static let legend = NSFont.systemFont(ofSize: 10.5)

        static let serviceName = NSFont.systemFont(ofSize: 13)
        static let serviceMessage = NSFont.systemFont(ofSize: 11)
        static let serviceArrow = NSFont.systemFont(ofSize: 11)

        static let rosterCount = NSFont.systemFont(ofSize: 13)
        static let rosterCountExpanded = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let rosterChevron = NSFont.systemFont(ofSize: 13)
        static let rosterRowName = NSFont.systemFont(ofSize: 12.5)

        /// Monogram shown on the chip when a service has no favicon on disk.
        static let faviconMonogram = NSFont.systemFont(ofSize: 11, weight: .semibold)

        static let footerWordmark = NSFont.systemFont(ofSize: 11, weight: .semibold)
        /// .02em at 11pt.
        static let footerWordmarkKerning: CGFloat = 0.22
        static let footerAction = NSFont.systemFont(ofSize: 11)

        static let emptyStateTitle = NSFont.systemFont(ofSize: 15, weight: .semibold)
        static let emptyStateSubtitle = NSFont.systemFont(ofSize: 11.5)
        static let emptyStateButton = NSFont.systemFont(ofSize: 12)

        static let verdictTitle = NSFont.systemFont(ofSize: 13, weight: .semibold)
        static let noConnectionNote = NSFont.systemFont(ofSize: 11.5)

        static let menuBarItem = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    }

    // MARK: - Colour

    enum Colors {
        // MARK: Panel
        //
        // The panel is a vibrancy material with the panel colour laid over it at 84%/86%, so the
        // desktop tints through. `panelSolid` is the same colour at full strength, for the few
        // places that need an opaque match — the dot's ring, and MBPopup's arrow fallback.

        static let panelSolid = dynamic(dark: NSColor(designHex: 0x211E1B), light: NSColor(designHex: 0xFBFAF8))
        /// What actually gets painted over the vibrancy view.
        static let panelTint = dynamic(
            dark: NSColor(designHex: 0x211E1B).withAlphaComponent(0.84),
            light: NSColor(designHex: 0xFBFAF8).withAlphaComponent(0.86)
        )

        static let panelBorder = dynamic(dark: whiteAlpha(0.12), light: blackAlpha(0.14))
        static let hairline = dynamic(dark: whiteAlpha(0.12), light: blackAlpha(0.1))
        /// Separators between rows *inside* a group sit a little lighter than the group's own edges.
        static let rowSeparator = dynamic(dark: whiteAlpha(0.09), light: blackAlpha(0.07))

        /// The 1pt line between the crown band and the status bar. Black in both appearances —
        /// it reads as the band's own shadow rather than a separator.
        static let crownSeam = blackAlpha(0.28)

        static let groupBackground = dynamic(dark: whiteAlpha(0.05), light: blackAlpha(0.04))
        static let groupBackgroundHover = dynamic(dark: whiteAlpha(0.08), light: blackAlpha(0.07))
        /// The expanded roster's header row, which sits on top of the group fill.
        static let groupHeaderBackground = dynamic(dark: whiteAlpha(0.05), light: blackAlpha(0.04))
        static let rosterRowHover = dynamic(dark: whiteAlpha(0.06), light: blackAlpha(0.05))

        /// Unfilled remainder of the status bar while a check is only partway through.
        static let statusBarTrack = dynamic(dark: whiteAlpha(0.08), light: blackAlpha(0.08))

        // MARK: Favicon chips
        //
        // Every favicon sits on a white chip: the shipped icons are a mixed bag (black marks on
        // transparency, full-colour marks, marks with their own tile) and none of them survive being
        // dropped straight onto the panel. The white chip also stops the fleet looking like sixteen
        // different treatments.

        static let chipBackground = NSColor.white
        static let chipMonogramBackground = whiteAlpha(0.08)
        /// Every chip sits inside a `PopupGroupBox`, so this is the panel colour as composited with
        /// the group fill on top of it — not the raw panel value, which reads as a visible ring
        /// rather than disappearing into the group's actual tint. Used for every chip's own edge,
        /// the severity dot's cutout ring, and the overlap ring in the collapsed roster stack, so
        /// all three blend into the cell instead of standing out as a drawn border.
        static let chipRing = dynamic(dark: NSColor(designHex: 0x2B2724), light: NSColor(designHex: 0xF7F5F2))

        // MARK: Text

        static let crownLabel = NSColor.white
        static let crownSecondaryLabel = whiteAlpha(0.72)
        static let crownButtonBackground = whiteAlpha(0.16)
        static let crownButtonBackgroundHover = whiteAlpha(0.28)

        static let legendLabel = dynamic(dark: whiteAlpha(0.5), light: blackAlpha(0.5))

        static let serviceName = dynamic(dark: .white, light: NSColor(designHex: 0x141414))
        static let serviceMessage = dynamic(dark: whiteAlpha(0.5), light: blackAlpha(0.55))
        static let serviceArrow = dynamic(dark: whiteAlpha(0.35), light: blackAlpha(0.32))

        static let rosterCount = dynamic(dark: .white, light: NSColor(designHex: 0x141414))
        static let rosterChevron = dynamic(dark: whiteAlpha(0.3), light: blackAlpha(0.28))
        static let rosterChevronExpanded = dynamic(dark: whiteAlpha(0.45), light: blackAlpha(0.45))
        static let rosterRowName = dynamic(dark: whiteAlpha(0.82), light: blackAlpha(0.78))
        static let rosterRowArrow = dynamic(dark: whiteAlpha(0.3), light: blackAlpha(0.3))

        static let footerWordmark = dynamic(dark: whiteAlpha(0.4), light: blackAlpha(0.35))
        static let footerAction = dynamic(dark: whiteAlpha(0.55), light: blackAlpha(0.5))
        static let footerActionHover = dynamic(dark: .white, light: NSColor(designHex: 0x141414))

        static let verdictLabel = dynamic(dark: .white, light: NSColor(designHex: 0x141414))
        static let timestampLabel = dynamic(dark: whiteAlpha(0.5), light: blackAlpha(0.5))
        static let separatorDot = dynamic(dark: whiteAlpha(0.18), light: blackAlpha(0.2))

        static let emptyStateTitle = dynamic(dark: whiteAlpha(0.8), light: blackAlpha(0.8))
        static let emptyStateSubtitle = dynamic(dark: whiteAlpha(0.42), light: blackAlpha(0.45))
        static let emptyStateButtonBackground = dynamic(dark: whiteAlpha(0.07), light: blackAlpha(0.06))
        static let emptyStateButtonBackgroundHover = dynamic(dark: whiteAlpha(0.12), light: blackAlpha(0.1))

        /// "Retry now" in the no-connection state.
        static let link = dynamic(dark: NSColor(designHex: 0x5B9DFF), light: NSColor(designHex: 0x0A66D6))

        // MARK: Status / severity — crown band, status bar and legend
        //
        // Carried over from Crown unchanged; the design says so explicitly. Deliberately muted:
        // full-strength red/orange/blue read as alarming across a whole colour band in a way they
        // don't as a 9pt dot.

        static let crownMajor = dynamic(dark: NSColor(designHex: 0xB8451F), light: NSColor(designHex: 0xB8451F))
        static let crownMinor = dynamic(dark: NSColor(designHex: 0xC4801F), light: NSColor(designHex: 0xC96A08))
        static let crownMaintenance = dynamic(dark: NSColor(designHex: 0x2B6491), light: NSColor(designHex: 0x2A6EA8))
        static let crownOperational = dynamic(dark: NSColor(designHex: 0x1F6B43), light: NSColor(designHex: 0x35845A))

        /// Grey means "couldn't determine", not "down". Not defined by the design — carried over.
        static let unknownBar = dynamic(dark: whiteAlpha(0.2), light: blackAlpha(0.16))

        // MARK: Status / severity — corner dots
        //
        // The brighter rail set, now used for the 9pt dot on each service's chip. Small marks need
        // more chroma than a colour band does.

        static let dotMajor = dynamic(dark: StatusColor.red, light: NSColor(designHex: 0xC9502A))
        static let dotMinor = dynamic(dark: StatusColor.orange, light: NSColor(designHex: 0xC4801F))
        static let dotMaintenance = dynamic(dark: NSColor(designHex: 0x4D9FD6), light: NSColor(designHex: 0x2A6EA8))
        static let dotOperational = crownOperational
        static let dotUnknown = dynamic(dark: whiteAlpha(0.32), light: blackAlpha(0.3))

        // MARK: Menu bar tick
        //
        // Resolved against the *menu bar's* appearance rather than the app's. Untouched by Native.

        static let menuBarOperational = dynamic(dark: StatusColor.green, light: NSColor(designHex: 0x4F9E68))
        static let menuBarMinor = dynamic(dark: StatusColor.orange, light: NSColor(designHex: 0xD1780A))
        static let menuBarMajor = StatusColor.red
        static let menuBarMaintenance = StatusColor.blue
        static let menuBarUnknown = dynamic(dark: whiteAlpha(0.32), light: blackAlpha(0.28))

        // MARK: Helpers

        private static func whiteAlpha(_ alpha: CGFloat) -> NSColor { .white.withAlphaComponent(alpha) }
        private static func blackAlpha(_ alpha: CGFloat) -> NSColor { .black.withAlphaComponent(alpha) }

        private static func dynamic(dark: NSColor, light: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                // `bestMatch` rather than comparing `appearance.name` directly, so the high-contrast
                // and vibrant variants resolve to the right side instead of silently falling back to
                // the light palette.
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            }
        }
    }

}

// MARK: - SwiftUI bridges

extension NSColor {
    /// The same colour for use in a SwiftUI view. Dynamic colours keep resolving per appearance
    /// after bridging, so light/dark still works without a `@Environment(\.colorScheme)` branch.
    var swiftUI: Color { Color(nsColor: self) }
}

extension NSFont {
    var swiftUI: Font { Font(self) }
}

extension NSColor {
    /// The designs quote plain sRGB hex literals; this maps them without going through string
    /// parsing that could silently yield black on a typo. Shared with `PreferencesLayout`.
    convenience init(designHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex & 0xFF0000) >> 16) / 255,
            green: CGFloat((hex & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hex & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
