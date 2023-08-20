//
//  PreferencesSidebarMenuItemCell.swift
//  PreferencesWindow
//

import Cocoa
import SFSafeSymbols

class PreferencesSidebarMenuItemCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier(String(describing: PreferencesSidebarMenuItemCell.self))

    var symbol: SFSymbol? {
        didSet {
            updateLabel()
        }
    }

    var title: String = "" {
        didSet {
            updateLabel()
        }
    }

    private lazy var titleLabel = NSTextField(labelWithString: "")
    private lazy var symbolImageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        for subview in [symbolImageView, titleLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        NSLayoutConstraint.activate([
            symbolImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            symbolImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            symbolImageView.heightAnchor.constraint(equalToConstant: 20),
            symbolImageView.widthAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: symbolImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.preferredFont(forTextStyle: .body)
    }

    private func updateLabel() {
        titleLabel.stringValue = title

        if let symbol {
            symbolImageView.image = NSImage(systemSymbol: symbol)
            symbolImageView.isHidden = false
        } else {
            symbolImageView.isHidden = true
        }
    }
}
