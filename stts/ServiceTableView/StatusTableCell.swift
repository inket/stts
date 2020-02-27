//
//  StatusTableCell.swift
//  stts
//

import Cocoa

class StatusTableCell: NSTableCellView {
    let statusIndicator = StatusIndicator()
    let statusField = NSTextField()

    enum Layout {
        static let verticalPadding: CGFloat = 6
        static let verticalSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let horizontalSpacing: CGFloat = 8

        static let titleFont = NSFont.systemFont(ofSize: 12)
        static let messageFont = NSFontManager.shared.font(
            withFamily: titleFont.fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: 10
        )

        static let titleHeight = NSLayoutManager().defaultLineHeight(for: titleFont)
        static let messageLineHeight = NSLayoutManager().defaultLineHeight(for: messageFont!)
        static let messageMaxHeight: CGFloat = 72 // 6 lines
        static let statusIndicatorSize = CGSize(width: 14, height: 14)

        static func availableStatusMessageWidth(fromTotalWidth totalWidth: CGFloat) -> CGFloat {
            totalWidth - horizontalPadding - statusIndicatorSize.width - horizontalSpacing - horizontalPadding
        }

        static func heightOfStatusMessage(_ message: String, width: CGFloat) -> CGFloat {
            // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html

            let statusMessageWidth = availableStatusMessageWidth(fromTotalWidth: width)

            let textStorage = NSTextStorage(string: message)
            let textContainer = NSTextContainer(containerSize: .init(width: statusMessageWidth, height: .infinity))
            let layoutManager = NSLayoutManager()

            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)

            let font = NSFont.systemFont(ofSize: 12)
            let italicFont = NSFontManager.shared.font(
                withFamily: font.fontName,
                traits: NSFontTraitMask.italicFontMask,
                weight: 5,
                size: 10
            )

            textStorage.addAttribute(
                .font,
                value: italicFont ?? font,
                range: NSRange(location: 0, length: (message as NSString).length)
            )

            textContainer.lineFragmentPadding = 0

            _ = layoutManager.glyphRange(for: textContainer)
            return min(messageMaxHeight, layoutManager.usedRect(for: textContainer).size.height)
        }

        static func heightOfRow(withMessage message: String, width: CGFloat) -> CGFloat {
            let statusMessageHeight = heightOfStatusMessage(message, width: width)

            // Hack to fix sizing… maybe caused by the font being italic? This probably stops working at line 12+
            let additionalHeight = CGFloat(Int(statusMessageHeight / messageLineHeight))

            return verticalPadding + titleHeight + verticalSpacing + statusMessageHeight + verticalPadding + additionalHeight
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
        statusIndicator.scaleUnitSquare(to: NSSize(width: 0.3, height: 0.3))
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusIndicator)

        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.isSelectable = false
        self.textField = textField

        textField.font = Layout.titleFont
        textField.textColor = NSColor.labelColor
        textField.backgroundColor = NSColor.clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

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
        statusField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusField)

        NSLayoutConstraint.activate([
            statusIndicator.heightAnchor.constraint(equalToConstant: Layout.statusIndicatorSize.height),
            statusIndicator.widthAnchor.constraint(equalToConstant: Layout.statusIndicatorSize.height),
            statusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            statusIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            textField.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            textField.heightAnchor.constraint(equalToConstant: Layout.titleHeight),
            textField.leadingAnchor.constraint(
                equalTo: statusIndicator.trailingAnchor,
                constant: Layout.horizontalSpacing
            ),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),

            statusField.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: Layout.verticalSpacing),
            statusField.leadingAnchor.constraint(
                equalTo: statusIndicator.trailingAnchor,
                constant: Layout.horizontalSpacing
            ),
            statusField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            statusField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding)
        ])
    }
}
