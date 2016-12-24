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
            checkmarkIcon.isHidden = status != .good && status != .maintenance || status == .undetermined
            crossIcon.isHidden = status == .good || status == .maintenance || status == .undetermined

            switch status {
            case .good: checkmarkIcon.color = StatusColor.green
            case .maintenance: checkmarkIcon.color = StatusColor.blue
            case .minor: crossIcon.color = StatusColor.orange
            case .major: crossIcon.color = StatusColor.red
            default: break
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
    static var green = NSColor(calibratedRed: 0.46, green: 0.78, blue: 0.56, alpha: 1)
    static var blue = NSColor(calibratedRed: 0.24, green: 0.54, blue: 1, alpha: 0.8)
    static var orange = NSColor.orange
    static var red = NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.23, alpha: 1)
}
