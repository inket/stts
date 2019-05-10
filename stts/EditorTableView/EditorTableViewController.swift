//
//  EditorTableViewController.swift
//  stts
//

import Cocoa

class EditorTableViewController: NSObject, SwitchableTableViewController {
    let contentView: NSStackView
    let scrollView: CustomScrollView
    let tableView = NSTableView()

    let allServices: [BaseService] = BaseService.all().sorted()
    var filteredServices: [BaseService]
    var selectedServices: [BaseService] = Preferences.shared.selectedServices

    var selectionChanged = false

    let settingsView = SettingsView()

    var hidden: Bool = true

    private var maxNameWidth: CGFloat? {
        didSet {
            if oldValue != maxNameWidth {
                tableView.tile()
            }
        }
    }

    init(contentView: NSStackView, scrollView: CustomScrollView) {
        self.contentView = contentView
        self.scrollView = scrollView
        self.filteredServices = allServices

        super.init()
        setup()
    }

    func setup() {
        tableView.frame = scrollView.bounds
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "editorColumnIdentifier"))
        column.width = 200
        tableView.addTableColumn(column)
        tableView.autoresizesSubviews = true
        tableView.wantsLayer = true
        tableView.layer?.cornerRadius = 6
        tableView.headerView = nil
        tableView.gridStyleMask = NSTableView.GridLineStyle.init(rawValue: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = NSColor.clear

        settingsView.isHidden = true
        settingsView.searchCallback = { [weak self] searchString in
            guard
                let strongSelf = self,
                let allServices = strongSelf.allServices as? [Service]
            else { return }

            if searchString.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                strongSelf.filteredServices = allServices
            } else {
                // Can't filter array with NSPredicate without making Service inherit KVO from NSObject, therefore we create
                // an array of service names that we can run the predicate on
                let allServiceNames = allServices.compactMap { $0.name } as NSArray
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", argumentArray: ["*\(searchString)*"])
                guard let filteredServiceNames = allServiceNames.filtered(using: predicate) as? [String] else { return }

                strongSelf.filteredServices = allServices.filter { filteredServiceNames.contains($0.name) }
            }

            strongSelf.tableView.reloadData()
        }

        settingsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(settingsView)

        NSLayoutConstraint.activate([
            settingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            settingsView.topAnchor.constraint(equalTo: contentView.topAnchor),
            settingsView.heightAnchor.constraint(equalToConstant: 130)
        ])
    }

    func willShow() {
        self.selectionChanged = false

        scrollView.topConstraint?.constant = settingsView.frame.size.height
        scrollView.documentView = tableView

        settingsView.isHidden = false

        // We should be using NSWindow's makeFirstResponder: instead of the search field's selectText:, but in this case, makeFirstResponder
        // is causing a bug where the search field "gets focused" twice (focus ring animation) the first time it's drawn.
        settingsView.searchField.selectText(nil)

        resizeViews()
    }

    func resizeViews() {
        tableView.frame = scrollView.bounds
        tableView.tableColumns.first?.width = tableView.frame.size.width

        scrollView.frame.size.height = 400

        (NSApp.delegate as? AppDelegate)?.popupController.resizePopup(
            height: scrollView.frame.size.height + 30 // bottomBar.frame.size.height
        )
    }

    func willOpenPopup() {
        resizeViews()
    }

    func didOpenPopup() {
        settingsView.searchField.window?.makeFirstResponder(settingsView.searchField)
    }

    func willHide() {
        settingsView.isHidden = true
    }
}

extension EditorTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredServices.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nil
    }
}

extension EditorTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard
            let maxNameWidth = maxNameWidth,
            let service = filteredServices[row] as? Service
        else { return EditorTableCell.defaultHeight }

        return service.name.height(forWidth: maxNameWidth, font: NSFont.systemFont(ofSize: 11)) + (8 * 2)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier(rawValue: "identifier")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) ?? EditorTableCell()

        guard let view = cell as? EditorTableCell else { return nil }
        guard let service = filteredServices[row] as? Service else { return nil }

        view.textField?.stringValue = service.name
        view.selected = selectedServices.contains(service)
        view.toggleCallback = { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.selectionChanged = true

            if view.selected {
                self?.selectedServices.append(service)
            } else {
                if let index = self?.selectedServices.firstIndex(of: service) {
                    self?.selectedServices.remove(at: index)
                }
            }

            Preferences.shared.selectedServices = strongSelf.selectedServices
        }

        maxNameWidth = EditorTableCell.maxNameWidth(for: tableView)

        return view
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "rowView")
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) ?? ServiceTableRowView()

        guard let view = cell as? ServiceTableRowView else { return nil }

        view.showSeparator = row + 1 < filteredServices.count

        return view
    }
}
