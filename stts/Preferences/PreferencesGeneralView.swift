//
//  PreferencesGeneralView.swift
//  stts
//

import Cocoa
import PreferencesWindow

class PreferencesGeneralView: VenturaPreferencesView {
    private let quitButton = NSButton(title: "Quit stts", target: NSApp, action: #selector(NSApplication.terminate(_:)))

    init(preferences: Preferences) {
        super.init(
            items: [
                .init(title: "First section"): [
                    .init(title: "Start at login", actions: [.switch(initialValue: true, changeCallback: { _ in })]),
                    .init(
                        title: "Notify when a status changes",
                        actions: [.switch(initialValue: true, changeCallback: { _ in })]
                    )
                ]
            ]
        )

        quitButton.bezelStyle = .rounded
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(quitButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 400),
            widthAnchor.constraint(equalToConstant: 400),

            quitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            quitButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class VenturaPreferencesView: NSView, PreferencesView {
    struct Section: Hashable {
        let id = UUID()
        let title: String?
    }

    struct Item: Hashable {
        let id = UUID()
        let title: String
        let actions: [Action]

        static func == (lhs: VenturaPreferencesView.Item, rhs: VenturaPreferencesView.Item) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    enum Action {
        case `switch`(initialValue: Bool, changeCallback: (_ newValue: Bool) -> Void)
    }

    final class Cell: NSTableCellView {
        static let identifier: NSUserInterfaceItemIdentifier = .init(String(describing: Cell.self))
        private let stackView = NSStackView()

        private let switchButton = NSSwitch()

        var text: String = "" {
            didSet {
                textField?.stringValue = text
            }
        }

        var actions: [Action] = [] {
            didSet {
                for control in [switchButton] {
                    control.isHidden = true
                }

                for action in actions {
                    switch action {
                    case let .switch(initialValue: initialValue, changeCallback: _):
                        switchButton.isHidden = false
                        switchButton.state = initialValue ? .on : .off
                    }
                }
            }
        }

        init() {
            super.init(frame: .zero)
            commonInit()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func commonInit() {
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.orientation = .horizontal
            addSubview(stackView)

            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.isSelectable = false
            self.textField = textField
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = NSColor.textColor
            textField.backgroundColor = NSColor.clear

            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            switchButton.target = self
            switchButton.action = #selector(changedSwitchValue)
            switchButton.controlSize = .mini

            for subview in [textField, spacer, switchButton] {
                stackView.addArrangedSubview(subview)
            }

            NSLayoutConstraint.activate([
                stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
                stackView.heightAnchor.constraint(equalTo: heightAnchor),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
            ])
        }

        @objc
        private func changedSwitchValue() {
            let switchIsOn = switchButton.state == .on || switchButton.state == .mixed
            for action in actions {
                switch action {
                case let .switch(initialValue: _, changeCallback: callback):
                    callback(switchIsOn)
                }
            }
        }
    }

    private let items: [Section: [Item]]
    private var flatItems: [Item] = []
    private let box = NSBox()
    private let tableView = NSTableView()

    init(items: [Section: [Item]]) {
        self.items = items
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        flatItems = items.values.flatMap { $0 }

        box.translatesAutoresizingMaskIntoConstraints = false
        box.titlePosition = .noTitle
        box.contentView = tableView
        box.contentViewMargins = NSSize(width: 0, height: 0)
        box.focusRingType = .none
        addSubview(box)

        let column = NSTableColumn(identifier: Cell.identifier)
        tableView.addTableColumn(column)
        tableView.autoresizesSubviews = true
        tableView.headerView = nil
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = NSColor.clear
        tableView.style = .fullWidth
        tableView.rowHeight = 36
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            box.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            box.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            tableView.topAnchor.constraint(equalTo: box.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
    }

    func willShow() {}
}

extension VenturaPreferencesView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        flatItems.count
    }
}

extension VenturaPreferencesView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Cell.identifier, owner: self) as? Cell ?? Cell()
        cell.text = flatItems[row].title
        cell.actions = flatItems[row].actions
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = SettingsTableRowView()
        rowView.showSeparator = row != 0
        return rowView
    }
}

private class SettingsTableRowView: NSTableRowView {
    var showSeparator = true

    override func drawSeparator(in dirtyRect: NSRect) {
        guard showSeparator else { return }
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}
