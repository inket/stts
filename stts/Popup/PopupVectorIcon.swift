//
//  PopupVectorIcon.swift
//  stts
//

import SwiftUI

/// A `Shape` built from SVG path data, scaled to fit its frame.
///
/// The popup's glyphs come from the design's own `icons/*.svg` exports, kept here as their original
/// path strings rather than transcribed into Swift bezier calls: it's a verbatim copy of the source
/// artwork, so there's nothing to get subtly wrong, and it stays diffable against the design.
///
/// Pure SwiftUI on purpose — wrapping the equivalent AppKit views in `NSViewRepresentable` works in
/// the running app but renders as a placeholder under `ImageRenderer`, which would blind the
/// snapshot tool (`Scripts/popup_snapshots.sh`) to exactly the part of the UI it's checking.
struct PopupVectorIcon: Shape {
    let pathData: String

    /// Side length of the square canvas `pathData` was authored against.
    var canvasSize: CGFloat = 46

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / canvasSize
        let path = Self.parse(pathData)

        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    /// Handles the subset of SVG path syntax these icons use: absolute `M`, `L`, `C` and `Z`.
    /// SVG and SwiftUI share a top-left origin with y increasing downward, so coordinates map over
    /// unchanged.
    private static func parse(_ data: String) -> Path {
        var path = Path()
        var numbers: [CGFloat] = []
        var command: Character?

        func flush() {
            guard let command else { return }

            switch command {
            case "M":
                for index in stride(from: 0, to: numbers.count - 1, by: 2) {
                    let point = CGPoint(x: numbers[index], y: numbers[index + 1])
                    // Repeated pairs after an `M` are implicit line-tos, per the SVG spec.
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            case "L":
                for index in stride(from: 0, to: numbers.count - 1, by: 2) {
                    path.addLine(to: CGPoint(x: numbers[index], y: numbers[index + 1]))
                }
            case "C":
                for index in stride(from: 0, to: numbers.count - 5, by: 6) {
                    path.addCurve(
                        to: CGPoint(x: numbers[index + 4], y: numbers[index + 5]),
                        control1: CGPoint(x: numbers[index], y: numbers[index + 1]),
                        control2: CGPoint(x: numbers[index + 2], y: numbers[index + 3])
                    )
                }
            case "Z":
                path.closeSubpath()
            default:
                break
            }

            numbers.removeAll(keepingCapacity: true)
        }

        var current = ""

        func flushNumber() {
            guard !current.isEmpty else { return }
            if let value = Double(current) { numbers.append(CGFloat(value)) }
            current = ""
        }

        for character in data {
            if character.isLetter {
                flushNumber()
                flush()
                command = character
            } else if character == "," || character.isWhitespace {
                flushNumber()
            } else {
                current.append(character)
            }
        }

        flushNumber()
        flush()

        return path
    }
}

extension PopupVectorIcon {
    /// Verbatim from the design's `icons/gear-*.svg` (both `<path>` elements concatenated — they
    /// share a fill, and the nonzero winding rule produces the cog's cutouts).
    static let gear = PopupVectorIcon(
        pathData: """
        M26.76,36.51 C27.11,36.51 27.44,36.70 27.62,37.01 L28.40,38.36 C28.93,39.28 30.21,39.63 \
        31.13,39.10 L32.87,38.10 C33.82,37.54 34.15,36.32 33.60,35.36 L32.82,34.02 C32.60,33.63 \
        32.66,33.14 32.98,32.82 C34.63,31.13 35.85,29.03 36.48,26.74 C36.60,26.31 36.99,26.01 \
        37.44,26.01 L39.00,26.01 C40.10,26.01 41.00,25.11 41.00,24.01 L41.00,22.01 C41.00,20.90 \
        40.10,20.01 39.00,20.01 L37.44,20.01 C36.99,20.01 36.60,19.71 36.48,19.27 C35.85,16.98 \
        34.63,14.88 32.98,13.19 C32.66,12.87 32.60,12.38 32.82,11.99 L33.60,10.65 C34.15,9.70 \
        33.82,8.47 32.87,7.92 L31.13,6.92 C30.21,6.38 28.93,6.74 28.40,7.65 L27.62,9.00 \
        C27.40,9.39 26.94,9.58 26.51,9.47 C24.14,8.86 21.86,8.86 19.49,9.47 C19.06,9.58 \
        18.60,9.39 18.38,9.00 L17.60,7.65 C17.07,6.74 15.79,6.38 14.87,6.92 L13.13,7.92 \
        C12.18,8.47 11.85,9.70 12.40,10.65 L13.18,11.99 C13.40,12.38 13.34,12.87 13.02,13.19 \
        C11.36,14.88 10.15,16.98 9.52,19.27 C9.40,19.71 9.01,20.01 8.56,20.01 L7.00,20.01 \
        C5.90,20.01 5.00,20.90 5.00,22.01 L5.00,24.01 C5.00,25.11 5.90,26.01 7.00,26.01 \
        L8.56,26.01 C9.01,26.01 9.40,26.31 9.52,26.74 C10.15,29.03 11.36,31.13 13.02,32.82 \
        C13.34,33.14 13.40,33.63 13.18,34.02 L12.40,35.36 C11.85,36.32 12.18,37.54 13.13,38.10 \
        L14.87,39.10 C15.79,39.63 17.07,39.27 17.60,38.36 L18.38,37.01 C18.60,36.62 19.06,36.43 \
        19.49,36.54 C21.86,37.16 24.14,37.16 26.51,36.55 C26.59,36.52 26.67,36.51 26.76,36.51 Z \
        M30.14,41.36 C28.71,41.36 27.38,40.60 26.67,39.36 L26.26,38.66 C24.06,39.12 21.94,39.12 \
        19.74,38.66 L19.33,39.36 C18.62,40.60 17.29,41.36 15.86,41.36 C15.16,41.36 14.47,41.18 \
        13.87,40.83 L12.13,39.83 C10.22,38.72 9.57,36.27 10.67,34.36 L11.07,33.66 C9.61,32.03 \
        8.50,30.10 7.81,28.01 L7.00,28.01 C4.79,28.01 3.00,26.21 3.00,24.01 L3.00,22.01 \
        C3.00,19.80 4.79,18.01 7.00,18.01 L7.81,18.01 C8.50,15.92 9.61,13.98 11.07,12.35 \
        L10.67,11.65 C9.57,9.74 10.22,7.29 12.13,6.19 L13.87,5.19 C14.47,4.84 15.16,4.65 \
        15.86,4.65 C17.29,4.65 18.62,5.42 19.33,6.65 L19.74,7.36 C21.94,6.89 24.06,6.89 \
        26.26,7.36 L26.67,6.65 C27.38,5.42 28.71,4.65 30.14,4.65 C30.84,4.65 31.53,4.84 \
        32.13,5.19 L33.87,6.19 C35.78,7.29 36.43,9.74 35.33,11.65 L34.93,12.35 C36.39,13.98 \
        37.50,15.92 38.19,18.01 L39.00,18.01 C41.21,18.01 43.00,19.80 43.00,22.01 L43.00,24.01 \
        C43.00,26.21 41.21,28.01 39.00,28.01 L38.19,28.01 C37.50,30.10 36.39,32.03 34.93,33.66 \
        L35.33,34.36 C36.43,36.27 35.78,38.72 33.87,39.83 L32.13,40.83 C31.53,41.18 30.84,41.36 \
        30.14,41.36 Z \
        M23.00,16.01 C19.14,16.01 16.00,19.15 16.00,23.01 C16.00,26.87 19.14,30.01 23.00,30.01 \
        C26.86,30.01 30.00,26.87 30.00,23.01 C30.00,19.15 26.86,16.01 23.00,16.01 Z \
        M23.00,32.01 C18.04,32.01 14.00,27.97 14.00,23.01 C14.00,18.04 18.04,14.01 23.00,14.01 \
        C27.96,14.01 32.00,18.04 32.00,23.01 C32.00,27.97 27.96,32.01 23.00,32.01 Z
        """
    )

    /// Verbatim from the design's `icons/refresh-*.svg`.
    static let refresh = PopupVectorIcon(
        pathData: """
        M23.00,43.00 L23.00,41.00 C32.93,41.00 41.00,32.93 41.00,23.00 C41.00,13.07 32.93,5.00 \
        23.00,5.00 C13.07,5.00 5.00,13.07 5.00,23.00 C5.00,29.63 8.63,35.71 14.47,38.86 \
        L13.53,40.62 C7.03,37.12 3.00,30.37 3.00,23.00 C3.00,11.97 11.97,3.00 23.00,3.00 \
        C34.03,3.00 43.00,11.97 43.00,23.00 C43.00,34.03 34.03,43.00 23.00,43.00 Z \
        M4.20,42.98 L3.80,41.02 L13.00,39.18 L13.00,30.00 L15.00,30.00 L15.00,40.00 \
        C15.00,40.48 14.66,40.89 14.20,40.98 L4.20,42.98 Z
        """
    )
}
