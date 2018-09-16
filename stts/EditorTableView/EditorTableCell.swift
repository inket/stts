//
//  EditorTableCell.swift
//  stts
//

import Cocoa
import SnapKit

class EditorTableCell: NSTableCellView {
    let toggleButton = NSButton()
    var selected: Bool = false {
        didSet {
            let color = selected ? StatusColor.green : StatusColor.darkGray
            let title = selected ? "ON" : "OFF"

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]

            toggleButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
            toggleButton.layer?.borderColor = color.cgColor
        }
    }

    var toggleCallback: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        self.textField = textField
        let font = NSFont.systemFont(ofSize: 11)
        textField.font = font
        textField.textColor = NSColor(calibratedWhite: 0, alpha: 0.8)
        textField.backgroundColor = NSColor.clear
        addSubview(textField)

        textField.snp.makeConstraints { make in
            make.left.equalTo(10)
            make.centerY.equalToSuperview()
        }

        addSubview(toggleButton)
        toggleButton.title = ""
        toggleButton.isBordered = false
        toggleButton.bezelStyle = .texturedSquare
        toggleButton.controlSize = .small
        toggleButton.target = self
        toggleButton.action = #selector(EditorTableCell.toggle)
        toggleButton.wantsLayer = true
        toggleButton.layer?.borderWidth = 1
        toggleButton.layer?.cornerRadius = 4
        toggleButton.snp.makeConstraints { make in
            make.left.equalTo(textField.snp.right).offset(-4)
            make.width.equalTo(36)
            make.right.equalTo(-10)
            make.height.equalTo(20)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("coder coder coder")
    }

    @objc func toggle() {
        self.selected = !selected
        toggleCallback()
    }
}
