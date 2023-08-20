//
//  EditorTableCell.swift
//  stts
//

import Cocoa

final class EditorTableCell: NSTableCellView {
    enum Design {
        static let padding = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        static let innerSpacing: CGFloat = 4

        enum Name {
            static let categoryFont = NSFont.systemFont(ofSize: 13, weight: .bold)
            static let font = NSFont.systemFont(ofSize: 13)
        }

        enum ToggleButton {
            static let size = NSSize(width: 36, height: 20)
        }

        enum ArrowImage {
            static let size = NSSize(width: 20, height: 20)
        }
    }

    enum CellType {
        case none
        case back
        case service
        case category
    }

    static let defaultHeight: CGFloat = 30

    private let stackView = NSStackView()
    private let leadingImageView = NSImageView()
    private lazy var backButton = NSButton(
        image: NSImage(systemSymbol: .chevronLeft),
        target: self,
        action: #selector(EditorTableCell.back)
    )
    private let toggleButton = NSButton()
    private let trailingImageView = NSImageView()

    var selected: Bool = false {
        didSet {
            setNeedsDisplay(frame)
        }
    }

    var toggleCallback: () -> Void = {}
    var backCallback: () -> Void = {}

    var type: CellType = .none {
        didSet {
            switch type {
            case .none:
                leadingImageView.isHidden = true
                backButton.isHidden = true
                textField?.isHidden = true
                toggleButton.isHidden = true
                trailingImageView.isHidden = true
            case .back:
                leadingImageView.isHidden = false
                backButton.isHidden = false
                textField?.isHidden = false
                toggleButton.isHidden = true
                trailingImageView.isHidden = true

                textField?.font = Design.Name.categoryFont
            case .service:
                leadingImageView.isHidden = true
                backButton.isHidden = true
                textField?.isHidden = false
                toggleButton.isHidden = false
                trailingImageView.isHidden = true

                textField?.font = Design.Name.font
            case .category:
                leadingImageView.isHidden = true
                backButton.isHidden = true
                textField?.isHidden = false
                toggleButton.isHidden = true
                trailingImageView.isHidden = false

                textField?.font = Design.Name.font
            }
        }
    }

    static func estimatedHeight(for serviceDefinition: ServiceDefinition, maxWidth: CGFloat) -> CGFloat {
        serviceDefinition.name.height(
            forWidth: maxWidth,
            font: Design.Name.font
        ) + Design.padding.top + Design.padding.bottom
    }

    static func maxNameWidth(for tableView: NSTableView) -> CGFloat {
        tableView.frame.size.width -
            Design.innerSpacing - Design.ToggleButton.size.width
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
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        addSubview(stackView)

        backButton.symbolConfiguration = NSImage.SymbolConfiguration(scale: .medium)
        backButton.controlSize = .large
        backButton.bezelStyle = .texturedRounded

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
        toggleButton.layer?.borderWidth = 1.5
        toggleButton.layer?.cornerRadius = 5

        leadingImageView.image = NSImage(systemSymbol: .chevronLeft)
        leadingImageView.symbolConfiguration = .init(pointSize: 14, weight: .medium)
        leadingImageView.contentTintColor = NSColor.tertiaryLabelColor

        trailingImageView.image = NSImage(systemSymbol: .chevronRight)
        trailingImageView.symbolConfiguration = .init(pointSize: 14, weight: .medium)
        trailingImageView.contentTintColor = NSColor.tertiaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        for subview in [backButton, textField, spacer, toggleButton, trailingImageView] {
            stackView.addArrangedSubview(subview)
        }

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            stackView.heightAnchor.constraint(equalTo: heightAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),

            backButton.widthAnchor.constraint(equalTo: backButton.heightAnchor),

            toggleButton.widthAnchor.constraint(equalToConstant: Design.ToggleButton.size.width),
            toggleButton.heightAnchor.constraint(equalToConstant: Design.ToggleButton.size.height),

            leadingImageView.widthAnchor.constraint(equalToConstant: Design.ArrowImage.size.width),
            leadingImageView.heightAnchor.constraint(equalToConstant: Design.ArrowImage.size.height),

            trailingImageView.widthAnchor.constraint(equalToConstant: Design.ArrowImage.size.width),
            trailingImageView.heightAnchor.constraint(equalToConstant: Design.ArrowImage.size.height)
        ])
    }

    @objc func toggle() {
        self.selected = !selected
        toggleCallback()
    }

    @objc func back() {
        backCallback()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let color = selected ? StatusColor.green : NSColor.tertiaryLabelColor
        let title = selected ? "ON" : "OFF"
        let backgroundColor = selected ? color.withAlphaComponent(0.1) : NSColor.clear

        toggleButton.title = title
        toggleButton.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        toggleButton.contentTintColor = color
        toggleButton.layer?.borderColor = color.cgColor
        toggleButton.layer?.backgroundColor = backgroundColor.cgColor
    }
}
