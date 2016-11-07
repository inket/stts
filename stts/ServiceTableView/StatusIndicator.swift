//
//  StatusIndicator.swift
//  stts
//
//  Created by inket on 31/10/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class StatusIndicator: NSView {
    var checkmarkIcon = CheckmarkIcon()
    var crossIcon = CrossIcon()
    var status: ServiceStatus = .good {
        didSet {
            checkmarkIcon.isHidden = status != .good || status == .undetermined
            crossIcon.isHidden = status == .good || status == .undetermined

            switch status {
            case .minor: crossIcon.color = NSColor.orange
            case .major: crossIcon.color = NSColor.red
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
