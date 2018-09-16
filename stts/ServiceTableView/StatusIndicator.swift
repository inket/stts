//
//  StatusIndicator.swift
//  stts
//

import Cocoa

class StatusIndicator: NSView {
    var checkmarkIcon = CheckmarkIcon()
    var crossIcon = CrossIcon()

    var status: ServiceStatus = .good {
        didSet {
            checkmarkIcon.isHidden = status > .maintenance
            crossIcon.isHidden = status <= .maintenance

            switch status {
            case .good: checkmarkIcon.color = StatusColor.green
            case .notice: checkmarkIcon.color = StatusColor.green
            case .maintenance: checkmarkIcon.color = StatusColor.blue
            case .minor: crossIcon.color = StatusColor.orange
            case .major: crossIcon.color = StatusColor.red
            case .undetermined: crossIcon.color = StatusColor.gray
            }
        }
    }

    init() {
        super.init(frame: NSRect.zero)

        addSubview(checkmarkIcon)
        addSubview(crossIcon)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        checkmarkIcon.frame = bounds
        crossIcon.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("coder pls")
    }
}

class StatusColor {
    static var green = NSColor(calibratedRed: 0.36, green: 0.68, blue: 0.46, alpha: 1)
    static var blue = NSColor(calibratedRed: 0.24, green: 0.54, blue: 1, alpha: 0.8)
    static var orange = NSColor.orange
    static var red = NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.23, alpha: 1)
    static var gray = NSColor(calibratedWhite: 0, alpha: 0.2)
    static var darkGray = NSColor(calibratedWhite: 0, alpha: 0.4)
}
