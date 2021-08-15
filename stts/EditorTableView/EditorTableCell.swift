//
//  EditorTableCell.swift
//  stts
//

import Cocoa

class EditorTableCell: NSTableCellView {
    enum Design {
        static let padding = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        static let innerSpacing: CGFloat = 4

        enum Name {
            static let font = NSFont.systemFont(ofSize: 12)
        }

        enum ToggleButton {
            static let size = NSSize(width: 36, height: 20)
        }

        enum ArrowImage {
            static let size = NSSize(width: 20, height: 20)
        }
    }

    enum CellType {
        case service
        case category
    }

    static let defaultHeight: CGFloat = 30

    let toggleButton = NSButton()
    let arrowImageView = NSImageView()

    var selected: Bool = false {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    var toggleCallback: () -> Void = {}

    var type: CellType = .service {
        didSet {
            switch type {
            case .service:
                toggleButton.isHidden = false
                arrowImageView.isHidden = true
            case .category:
                toggleButton.isHidden = true
                arrowImageView.isHidden = false
            }
        }
    }

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

        toggleButton.title = ""
        toggleButton.isBordered = false
        toggleButton.bezelStyle = .texturedSquare
        toggleButton.controlSize = .small
        toggleButton.target = self
        toggleButton.action = #selector(EditorTableCell.toggle)
        toggleButton.wantsLayer = true
        toggleButton.layer?.borderWidth = 1
        toggleButton.layer?.cornerRadius = 4

        arrowImageView.image = NSImage(named: "NSGoRightTemplate")

        [textField, toggleButton, arrowImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.padding.left),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),

            toggleButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: textField.trailingAnchor,
                constant: Design.innerSpacing
            ),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.padding.right),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: Design.ToggleButton.size.width),
            toggleButton.heightAnchor.constraint(equalToConstant: Design.ToggleButton.size.height),

            arrowImageView.leadingAnchor.constraint(
                greaterThanOrEqualTo: textField.trailingAnchor,
                constant: Design.innerSpacing
            ),
            arrowImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.padding.right),
            arrowImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: Design.ArrowImage.size.width),
            arrowImageView.heightAnchor.constraint(equalToConstant: Design.ArrowImage.size.height)
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
