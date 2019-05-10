//
//  EditorTableCell.swift
//  stts
//

import Cocoa

class EditorTableCell: NSTableCellView {
    private enum Design {
        static let padding = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        static let innerSpacing: CGFloat = 4

        enum Name {
            static let font = NSFont.systemFont(ofSize: 11)
        }

        enum ToggleButton {
            static let size = NSSize(width: 36, height: 20)
        }
    }

    static let defaultHeight: CGFloat = 30

    let toggleButton = NSButton()
    var selected: Bool = false {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    var toggleCallback: () -> Void = {}

    static func estimatedHeight(for service: Service, maxWidth: CGFloat) -> CGFloat {
        return
            service.name.height(forWidth: maxWidth, font: Design.Name.font) +
            Design.padding.top + Design.padding.bottom
    }

    static func maxNameWidth(for tableView: NSTableView) -> CGFloat {
        return tableView.frame.size.width -
            Design.padding.left - Design.innerSpacing - Design.ToggleButton.size.width - Design.padding.right
    }

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
        textField.font = Design.Name.font
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
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.padding.left),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),

            toggleButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: Design.innerSpacing),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.padding.right),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: Design.ToggleButton.size.width),
            toggleButton.heightAnchor.constraint(equalToConstant: Design.ToggleButton.size.height)
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
