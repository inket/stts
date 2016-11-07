//
//  BottomBar.swift
//  stts
//
//  Created by inket on 1/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import SnapKit

class BottomBar: NSView {
    let settingsButton = NSButton()
    let statusField = NSTextField()
    let separator = CustomRowView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(separator)

        separator.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.left.top.right.equalTo(0)
        }

        let gearIcon = GearIcon()
        addSubview(settingsButton)
        settingsButton.addSubview(gearIcon)
        settingsButton.isBordered = false
        settingsButton.bezelStyle = .regularSquare
        settingsButton.title = ""
        settingsButton.snp.makeConstraints { make in
            make.height.width.equalTo(30)
            make.bottom.left.equalTo(0)
        }

        gearIcon.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        gearIcon.scaleUnitSquare(to: NSSize(width: 0.46, height: 0.46))

        addSubview(statusField)

        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isSelectable = false
        let font = NSFont.systemFont(ofSize: 12)
        let italicFont = NSFontManager.shared().font(withFamily: font.fontName,
                                                     traits: NSFontTraitMask.italicFontMask,
                                                     weight: 5,
                                                     size: 10)
        statusField.font = italicFont
        statusField.textColor = NSColor(calibratedWhite: 0, alpha: 0.6)
        statusField.maximumNumberOfLines = 1
        statusField.stringValue = "Last checked now"
        statusField.backgroundColor = NSColor.clear
        statusField.alignment = .center
        statusField.cell?.truncatesLastVisibleLine = true

        statusField.snp.makeConstraints { make in
            make.left.equalTo(settingsButton.snp.right)
            make.right.equalTo(-4)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
