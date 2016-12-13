//
//  ServiceTableRowView.swift
//  stts
//

import Cocoa

class ServiceTableRowView: NSTableRowView {
    var showSeparator = true
    var gradient: CAGradientLayer?

    override func layout() {
        super.layout()

        let width = frame.size.width
        let height = frame.size.height

        let gradient = self.gradient ?? CAGradientLayer()

        gradient.isHidden = !showSeparator

        self.wantsLayer = true
        self.layer?.insertSublayer(gradient, at: 0)
        self.gradient = gradient

        let gray = NSColor(calibratedWhite: 0, alpha: 0.05).cgColor
        gradient.colors = [NSColor.clear.cgColor, gray, gray, gray, NSColor.clear.cgColor]
        gradient.locations = [0, 0.3, 0.5, 0.70, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = CGRect(x: 0, y: height - 1, width: width, height: 1)
    }
}
