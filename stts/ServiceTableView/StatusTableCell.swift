//
//  StatusTableCell.swift
//  stts
//

import Cocoa

class StatusTableCell: NSTableCellView {
    let statusIndicator = StatusIndicator()
    let statusField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        statusIndicator.scaleUnitSquare(to: NSSize(width: 0.3, height: 0.3))
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusIndicator)

        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        self.textField = textField
        let font = NSFont.systemFont(ofSize: 12)
        textField.font = font
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isSelectable = false

        let italicFont = NSFontManager.shared.font(
            withFamily: font.fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: 10
        )
        statusField.font = italicFont
        statusField.textColor = NSColor.secondaryLabelColor
        statusField.maximumNumberOfLines = 1
        statusField.cell!.truncatesLastVisibleLine = true
        statusField.backgroundColor = NSColor.clear
        statusField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusField)

        NSLayoutConstraint.activate([
            statusIndicator.heightAnchor.constraint(equalToConstant: 14),
            statusIndicator.widthAnchor.constraint(equalToConstant: 14),
            statusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            textField.heightAnchor.constraint(equalToConstant: 18),
            textField.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),

            statusField.heightAnchor.constraint(equalToConstant: 18),
            statusField.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            statusField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            statusField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 10)
        ])
    }
}
