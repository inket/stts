//
//  StatusTableCell.swift
//  stts
//

import Cocoa

class StatusTableCell: NSTableCellView {
    let statusIndicator = StatusIndicator()

    let stackView = NSStackView()
    let titleField = NSTextField()
    let statusField = NSTextField()

    var hideGoodStatus = false

    enum Layout {
        static let verticalPadding: CGFloat = 10
        static let verticalSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let horizontalSpacing: CGFloat = 8

        static let titleFont = NSFont.systemFont(ofSize: 13)
        static let messageFont = NSFontManager.shared.font(
            withFamily: titleFont.fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: 11
        )

        static let statusIndicatorSize = CGSize(width: 14, height: 14)

        private static let dummyCell = StatusTableCell(frame: .zero)
        static func heightOfRow(for service: Service, width: CGFloat) -> CGFloat {
            let nsScrollerWidth: CGFloat = 16
            let realRowWidth = width - (nsScrollerWidth - 4) // 4 by trial & error

            dummyCell.frame.size = CGSize(width: realRowWidth, height: 400)
            dummyCell.setup(with: service)
            dummyCell.layoutSubtreeIfNeeded()

            return dummyCell.stackView.frame.size.height + (verticalPadding * 2)
        }
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
        textField?.removeFromSuperview()

        statusIndicator.scaleUnitSquare(to: NSSize(width: 0.3, height: 0.3))
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusIndicator)

        stackView.orientation = .vertical
        stackView.distribution = .fill
        stackView.alignment = .leading
        stackView.spacing = Layout.verticalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        titleField.isEditable = false
        titleField.isBordered = false
        titleField.isSelectable = false
        titleField.maximumNumberOfLines = 2
        titleField.cell!.truncatesLastVisibleLine = true
        titleField.cell!.lineBreakMode = .byWordWrapping
        titleField.cell!.wraps = true

        titleField.font = Layout.titleFont
        titleField.textColor = NSColor.labelColor
        titleField.backgroundColor = NSColor.clear

        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isSelectable = false

        statusField.font = Layout.messageFont
        statusField.textColor = NSColor.secondaryLabelColor
        statusField.maximumNumberOfLines = 6
        statusField.cell!.truncatesLastVisibleLine = true
        statusField.cell!.lineBreakMode = .byWordWrapping
        statusField.cell!.wraps = true
        statusField.backgroundColor = NSColor.clear

        [titleField, statusField].forEach {
            stackView.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            statusIndicator.heightAnchor.constraint(equalToConstant: Layout.statusIndicatorSize.height),
            statusIndicator.widthAnchor.constraint(equalToConstant: Layout.statusIndicatorSize.height),
            statusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            stackView.leadingAnchor.constraint(
                equalTo: statusIndicator.trailingAnchor,
                constant: Layout.horizontalSpacing
            ),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding)
        ])
    }

    func setup(with service: Service) {
        titleField.stringValue = service.name
        statusIndicator.status = service.status
        statusField.stringValue = service.message
        statusField.isHidden = service.status == .good && Preferences.shared.hideGoodStatusMessage
    }
}
