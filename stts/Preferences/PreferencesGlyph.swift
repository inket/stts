//
//  PreferencesGlyph.swift
//  stts
//

import AppKit

/// The settings sidebar's icons, drawn from the design doc's own SVG path data.
///
/// These were SF Symbols (`gearshape.fill`, `list.bullet`, `plus.app`, `info.circle.fill`) until it
/// became clear the four can't be made to sit right together. An SF Symbol is a *font glyph*: it's
/// laid out against text metrics, with optical bearings and padding chosen per symbol for use
/// inline with text, not for centring inside a fixed tile. So at any one point size some of them
/// centre correctly and others sit a point high or read as slightly the wrong shape — and changing
/// the size just moves the problem to a different symbol. Correcting that per symbol meant
/// hand-tuned offsets, which is a treadmill rather than a fix.
///
/// The design doc draws its own glyphs instead, all on a shared 16×16 canvas at a common stroke
/// weight, so they're consistent with each other by construction and centred by their geometry.
/// Transcribed here as bezier calls rather than shipped as image assets: they're a handful of
/// circles, rounded rects and straight lines, and in code they stay resolution-independent, scale
/// to whatever the tile asks for, and tint as template images. `PopupVectorIcon` does the
/// equivalent for the popup's glyphs (as a SwiftUI `Shape`, which is what that side needs).
enum PreferencesGlyph {
    case general
    case services
    case customServices
    case about

    /// The canvas every coordinate below is authored against — the design's `viewBox="0 0 16 16"`.
    static let canvas: CGFloat = 16

    /// A template image of the glyph, so `NSImageView.contentTintColor` recolours it white on the
    /// tile. Sized to the canvas by default; it redraws for whatever rect it's asked to fill, so
    /// the tile can scale it without going soft.
    func image(size: CGFloat = PreferencesGlyph.canvas) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            // Scale from `rect`, not the declared size: an `NSImage` built this way re-runs this
            // handler for whatever rect it's drawn into, which is what keeps it crisp at any size
            // and on any display scale.
            let scale = min(rect.width, rect.height) / Self.canvas
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: scale, y: scale)

            NSColor.black.setFill()
            NSColor.black.setStroke()
            self.draw()

            return true
        }

        image.isTemplate = true
        return image
    }

    /// SVG's y axis points down, and the drawing handler above is flipped to match, so every
    /// coordinate here is a verbatim copy of the design's own.
    private func draw() {
        switch self {
        case .general:
            // <circle cx="8" cy="8" r="2.1" fill="none" stroke-width="1.4"/>
            // <path d="M8 1.6v1.8M8 12.6v1.8M1.6 8h1.8M12.6 8h1.8
            //          M3.5 3.5l1.3 1.3M11.2 11.2l1.3 1.3M12.5 3.5l-1.3 1.3M4.8 11.2l-1.3 1.3"
            //       stroke-width="1.4" stroke-linecap="round"/>
            Self.strokeCircle(centeredAt: NSPoint(x: 8, y: 8), radius: 2.1, lineWidth: 1.4)
            Self.strokeLines(
                [
                    (NSPoint(x: 8, y: 1.6), NSPoint(x: 8, y: 3.4)),
                    (NSPoint(x: 8, y: 12.6), NSPoint(x: 8, y: 14.4)),
                    (NSPoint(x: 1.6, y: 8), NSPoint(x: 3.4, y: 8)),
                    (NSPoint(x: 12.6, y: 8), NSPoint(x: 14.4, y: 8)),
                    (NSPoint(x: 3.5, y: 3.5), NSPoint(x: 4.8, y: 4.8)),
                    (NSPoint(x: 11.2, y: 11.2), NSPoint(x: 12.5, y: 12.5)),
                    (NSPoint(x: 12.5, y: 3.5), NSPoint(x: 11.2, y: 4.8)),
                    (NSPoint(x: 4.8, y: 11.2), NSPoint(x: 3.5, y: 12.5))
                ],
                lineWidth: 1.4
            )

        case .services:
            // <circle cx="3.6" cy="4.4" r="1.15"/><circle cx="3.6" cy="11.6" r="1.15"/>
            // <rect x="7" y="3.6" width="6" height="1.6" rx=".8"/>
            // <rect x="7" y="10.8" width="6" height="1.6" rx=".8"/>
            Self.fillCircle(centeredAt: NSPoint(x: 3.6, y: 4.4), radius: 1.15)
            Self.fillCircle(centeredAt: NSPoint(x: 3.6, y: 11.6), radius: 1.15)
            Self.fillRoundedRect(NSRect(x: 7, y: 3.6, width: 6, height: 1.6), radius: 0.8)
            Self.fillRoundedRect(NSRect(x: 7, y: 10.8, width: 6, height: 1.6), radius: 0.8)

        case .customServices:
            // <rect x="2.4" y="2.4" width="11.2" height="11.2" rx="3" fill="none" stroke-width="1.4"/>
            // <path d="M8 5.6v4.8M5.6 8h4.8" stroke-width="1.4" stroke-linecap="round"/>
            Self.strokeRoundedRect(
                NSRect(x: 2.4, y: 2.4, width: 11.2, height: 11.2),
                radius: 3,
                lineWidth: 1.4
            )
            Self.strokeLines(
                [
                    (NSPoint(x: 8, y: 5.6), NSPoint(x: 8, y: 10.4)),
                    (NSPoint(x: 5.6, y: 8), NSPoint(x: 10.4, y: 8))
                ],
                lineWidth: 1.4
            )

        case .about:
            // <circle cx="8" cy="8" r="6.2" fill="none" stroke-width="1.4"/>
            // <path d="M8 7.1v4" stroke-width="1.5" stroke-linecap="round"/>
            // <circle cx="8" cy="4.9" r=".85"/>
            Self.strokeCircle(centeredAt: NSPoint(x: 8, y: 8), radius: 6.2, lineWidth: 1.4)
            Self.strokeLines([(NSPoint(x: 8, y: 7.1), NSPoint(x: 8, y: 11.1))], lineWidth: 1.5)
            Self.fillCircle(centeredAt: NSPoint(x: 8, y: 4.9), radius: 0.85)
        }
    }

    // MARK: - Primitives

    private static func fillCircle(centeredAt center: NSPoint, radius: CGFloat) {
        NSBezierPath(ovalIn: circleRect(centeredAt: center, radius: radius)).fill()
    }

    private static func strokeCircle(centeredAt center: NSPoint, radius: CGFloat, lineWidth: CGFloat) {
        let path = NSBezierPath(ovalIn: circleRect(centeredAt: center, radius: radius))
        path.lineWidth = lineWidth
        path.stroke()
    }

    private static func circleRect(centeredAt center: NSPoint, radius: CGFloat) -> NSRect {
        NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private static func fillRoundedRect(_ rect: NSRect, radius: CGFloat) {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    private static func strokeRoundedRect(_ rect: NSRect, radius: CGFloat, lineWidth: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = lineWidth
        path.stroke()
    }

    /// Straight segments, all with the design's round caps.
    private static func strokeLines(_ lines: [(NSPoint, NSPoint)], lineWidth: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round

        for (start, end) in lines {
            path.move(to: start)
            path.line(to: end)
        }

        path.stroke()
    }
}
