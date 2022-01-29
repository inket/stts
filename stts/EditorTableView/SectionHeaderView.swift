//
//  SectionHeaderView.swift
//  stts
//

import Cocoa

class SectionHeaderView: NSTextField {
    init(name: String) {
        super.init(frame: .zero)

        setup()
        self.stringValue = name
    }

    required init?(coder: NSCoder) {
        super.init(frame: .zero)
        setup()
    }

    private func setup() {
        self.isEditable = false
        self.isBordered = false
        self.isSelectable = false

        let fontSize = NSFont.systemFontSize(for: .regular)
        let font = NSFont.systemFont(ofSize: fontSize)
        let italicFont = NSFontManager.shared.font(
            withFamily: font.fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: fontSize
        )
        self.font = italicFont

        self.textColor = NSColor.secondaryLabelColor
        self.maximumNumberOfLines = 1
        self.cell!.truncatesLastVisibleLine = true
        self.backgroundColor = NSColor.clear
    }
}
