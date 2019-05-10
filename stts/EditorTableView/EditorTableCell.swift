//
//  EditorTableCell.swift
//  stts
//

import Cocoa

class EditorTableCell: NSTableCellView {
    let toggleButton = NSButton()
    var selected: Bool = false {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    var toggleCallback: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        self.textField = textField
        let font = NSFont.systemFont(ofSize: 11)
        textField.font = font
        textField.textColor = NSColor.textColor
        textField.backgroundColor = NSColor.clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        toggleButton.translatesAutoresizingMaskIntoConstraints = false
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

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),

            toggleButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 4),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: 36),
            toggleButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    @objc func toggle() {
        self.selected = !selected
        toggleCallback()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let color = selected ? StatusColor.green : NSColor.tertiaryLabelColor
        let title = selected ? "ON" : "OFF"

        if #available(OSX 10.14, *) {
            toggleButton.title = title
            toggleButton.font = NSFont.systemFont(ofSize: 11)
            toggleButton.contentTintColor = color
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]

            toggleButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        }

        toggleButton.layer?.borderColor = color.cgColor
    }
}
