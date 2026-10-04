//
//  EmptyStateIllustration.swift
//  stts
//

import SwiftUI

struct EmptyStateIllustration: View {
    enum Kind {
        case addServices
        case allClear
    }

    let kind: Kind
    var width: CGFloat = PopupLayout.EmptyState.illustrationSize

    private typealias Colors = PopupLayout.Colors

    private static let gridSize: CGFloat = 96
    private static let visibleRows: ClosedRange<CGFloat> = 30...78

    private static let chipOrigins: [CGFloat] = [19.8, 33.8, 47.8]
    private static let chipTop: CGFloat = 33.8
    private static let chipSize: CGFloat = 28.4
    private static let chipCornerRadius: CGFloat = 8
    private static let chipLineWidth: CGFloat = 1.6
    private static let overlapGap: CGFloat = 1.8

    private static let badgeCenter = CGPoint(x: 72, y: 62)
    private static let badgeRadius: CGFloat = 9.2
    private static let glyphLineWidth: CGFloat = 1.8

    var body: some View {
        let scale = width / Self.gridSize

        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: 0, y: -Self.visibleRows.lowerBound)

            switch kind {
            case .addServices: drawAddServices(in: &context)
            case .allClear: drawAllClear(in: &context)
            }
        }
        .frame(width: width, height: (Self.visibleRows.upperBound - Self.visibleRows.lowerBound) * scale)
        .accessibilityHidden(true)
    }

    private func drawAddServices(in context: inout GraphicsContext) {
        drawBackChips(in: &context)
        drawChip(
            at: Self.chipOrigins[2],
            color: Colors.illustrationChipFront,
            style: StrokeStyle(lineWidth: Self.chipLineWidth, dash: [4, 4]),
            in: &context
        )

        var plus = Path()
        plus.move(to: CGPoint(x: 62, y: 42.8))
        plus.addLine(to: CGPoint(x: 62, y: 53.2))
        plus.move(to: CGPoint(x: 56.8, y: 48))
        plus.addLine(to: CGPoint(x: 67.2, y: 48))
        context.stroke(
            plus,
            with: .color(Colors.illustrationAccent.swiftUI),
            style: StrokeStyle(lineWidth: Self.glyphLineWidth, lineCap: .round)
        )
    }

    private func drawAllClear(in context: inout GraphicsContext) {
        drawBackChips(in: &context)
        drawChip(
            at: Self.chipOrigins[2],
            color: Colors.illustrationChipFrontSettled,
            style: StrokeStyle(lineWidth: Self.chipLineWidth),
            in: &context
        )

        let badge = Path(ellipseIn: square(around: Self.badgeCenter, radius: Self.badgeRadius))
        erase(Path(ellipseIn: square(around: Self.badgeCenter, radius: Self.badgeRadius + 3.6)), in: &context)
        context.stroke(badge, with: .color(Colors.illustrationAccent.swiftUI), lineWidth: Self.chipLineWidth)

        var tick = Path()
        tick.move(to: CGPoint(x: 67.8, y: 62.2))
        tick.addLine(to: CGPoint(x: 70.9, y: 65.2))
        tick.addLine(to: CGPoint(x: 76.3, y: 58.9))
        context.stroke(
            tick,
            with: .color(Colors.illustrationAccent.swiftUI),
            style: StrokeStyle(lineWidth: Self.glyphLineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawBackChips(in context: inout GraphicsContext) {
        let style = StrokeStyle(lineWidth: Self.chipLineWidth)
        drawChip(at: Self.chipOrigins[0], color: Colors.illustrationChipBack, style: style, in: &context)
        drawChip(at: Self.chipOrigins[1], color: Colors.illustrationChipMiddle, style: style, in: &context)
    }

    private func drawChip(at x: CGFloat, color: NSColor, style: StrokeStyle, in context: inout GraphicsContext) {
        let chip = CGRect(x: x, y: Self.chipTop, width: Self.chipSize, height: Self.chipSize)
        let gap = chip.insetBy(dx: -Self.overlapGap, dy: -Self.overlapGap)

        erase(Path(roundedRect: gap, cornerRadius: Self.chipCornerRadius + Self.overlapGap), in: &context)
        context.stroke(
            Path(roundedRect: chip, cornerRadius: Self.chipCornerRadius),
            with: .color(color.swiftUI),
            style: style
        )
    }

    /// Erased rather than painted in the panel colour: the popup sits on vibrancy, so no solid
    /// colour would match what's behind it.
    private func erase(_ path: Path, in context: inout GraphicsContext) {
        var eraser = context
        eraser.blendMode = .destinationOut
        eraser.fill(path, with: .color(.black))
    }

    private func square(around center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
