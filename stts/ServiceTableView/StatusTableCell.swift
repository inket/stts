//
//  StatusTableCell.swift
//  stts
//
//  Created by inket on 24/10/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import SnapKit

class StatusTableCell: NSTableCellView {
    let statusIndicator = StatusIndicator()
    let statusField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        statusIndicator.scaleUnitSquare(to: NSSize(width: 0.3, height: 0.3))
        addSubview(statusIndicator)

        statusIndicator.snp.makeConstraints { make in
            make.height.width.equalTo(14)
            make.left.equalTo(8)
            make.centerY.equalToSuperview()
        }

        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        self.textField = textField
        let font = NSFont.systemFont(ofSize: 12)
        textField.font = font
        textField.textColor = NSColor(calibratedWhite: 0, alpha: 0.8)
        addSubview(textField)

        textField.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.leading.equalTo(statusIndicator.snp.trailing).offset(4)
            make.trailing.equalTo(8)
            make.centerY.equalToSuperview().offset(-8)
        }

        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isSelectable = false
        let italicFont = NSFontManager.shared().font(withFamily: font.fontName,
                                                     traits: NSFontTraitMask.italicFontMask,
                                                     weight: 5,
                                                     size: 10)
        statusField.font = italicFont
        statusField.textColor = NSColor(calibratedWhite: 0, alpha: 0.5)
        statusField.maximumNumberOfLines = 1
        statusField.cell!.truncatesLastVisibleLine = true
        addSubview(statusField)

        statusField.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.leading.equalTo(statusIndicator.snp.trailing).offset(4)
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview().offset(10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("ain't nobody got time for the coder init")
    }
}
