//
//  PreferencesGeneralView.swift
//  stts
//

import Cocoa
import PreferencesWindow

class PreferencesGeneralView: VenturaPreferencesView {
    init() {
        super.init(
            items: [
                .init(title: "First section"): [
                    .init(title: "Start at login", actions: [.switch(initialValue: true, changeCallback: { _ in })]),
                    .init(
                        title: "Notify when a status changes",
                        actions: [.switch(initialValue: true, changeCallback: { _ in })]
                    ),
                    .init(
                        title: "Hide details of available services",
                        actions: [.switch(initialValue: false, changeCallback: { _ in })]
                    )
                ]
            ]
        )

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 400),
            widthAnchor.constraint(equalToConstant: 400),
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
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
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
//    private let stackView = NSStackView()
    private let box = NSBox()
    private let tableView = NSTableView()

    private lazy var dataSource = NSTableViewDiffableDataSource<Section, Item>(
        tableView: tableView
    ) { tableView, tableColumn, row, item in
        let cell = tableView.makeView(withIdentifier: Cell.identifier, owner: self) as? Cell ?? Cell()

        cell.text = item.title
        cell.actions = item.actions

        return cell
    }

    init(items: [Section: [Item]]) {
        self.items = items
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
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
        tableView.dataSource = dataSource
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
            tableView.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        reloadData()
    }

    private func reloadData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        for (section, sectionItems) in items {
            snapshot.appendSections([section])
            snapshot.appendItems(sectionItems)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func willShow() {}
}

extension VenturaPreferencesView: NSTableViewDelegate {

}
