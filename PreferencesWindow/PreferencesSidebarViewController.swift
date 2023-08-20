//
//  PreferencesSidebarViewController.swift
//  PreferencesWindow
//

import Cocoa

class PreferencesSidebarTableView: NSTableView {
    override func makeView(withIdentifier identifier: NSUserInterfaceItemIdentifier, owner: Any?) -> NSView? {
        if identifier.rawValue == "NSTableViewRowViewKey" {
            return PreferencesSidebarRowView()
        } else {
            return super.makeView(withIdentifier: identifier, owner: owner)
        }
    }
}

class PreferencesSidebarViewController: NSViewController {
    private let tableView = PreferencesSidebarTableView()
    private lazy var dataSource: NSTableViewDiffableDataSource<
        PreferencesSidebarMenuSection,
        PreferencesSidebarMenuItem
    > = .init(tableView: tableView) { tableView, tableColumn, row, sidebarMenuItem in
        let cell = tableView.makeView(
            withIdentifier: PreferencesSidebarMenuItemCell.identifier,
            owner: self
        ) as? PreferencesSidebarMenuItemCell ?? PreferencesSidebarMenuItemCell()

        cell.title = sidebarMenuItem.title
        cell.symbol = sidebarMenuItem.symbol

        return cell
    }

    private let menuItems: [PreferencesSidebarMenuItem]

    var onSelectionChange: ((PreferencesSidebarMenuItem) -> Void)?

    init(menuItems: [PreferencesSidebarMenuItem]) {
        self.menuItems = menuItems
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        for subview in [tableView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 160),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])

        tableView.delegate = self
        tableView.focusRingType = .none
        tableView.addTableColumn(NSTableColumn(identifier: .init("only-column")))
        tableView.dataSource = dataSource

        updateDataSource()

        tableView.selectRowIndexes(.init(integer: 0), byExtendingSelection: false)
        onSelectionChange?(menuItems[0])
    }

    private func updateDataSource() {
        var snapshot = NSDiffableDataSourceSnapshot<PreferencesSidebarMenuSection, PreferencesSidebarMenuItem>()
        snapshot.appendSections([.menu])
        snapshot.appendItems(
            menuItems,
            toSection: .menu
        )
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension PreferencesSidebarViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelectionChange?(menuItems[tableView.selectedRow])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        tableView.makeView(
            withIdentifier: PreferencesSidebarRowView.identifier,
            owner: self
        ) as? PreferencesSidebarRowView ?? PreferencesSidebarRowView()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        PreferencesSidebarRowView.height
    }
}
