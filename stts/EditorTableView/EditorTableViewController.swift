//
//  EditorTableViewController.swift
//  stts
//

import Cocoa
import SnapKit

class EditorTableViewController: NSObject, SwitchableTableViewController {
    let contentView: NSStackView
    let scrollView: CustomScrollView
    let tableView = NSTableView()

    let allServices: [Service] = Service.all().sorted()
    var filteredServices: [Service]
    var selectedServices: [Service] = Preferences.shared.selectedServices

    var selectionChanged = false

    let settingsView = SettingsView()

    var hidden: Bool = true

    init(contentView: NSStackView, scrollView: CustomScrollView) {
        self.contentView = contentView
        self.scrollView = scrollView
        self.filteredServices = allServices

        super.init()
        setup()
    }

    func setup() {
        tableView.frame = scrollView.bounds
        let column = NSTableColumn(identifier: "editorColumnIdentifier")
        column.width = 200
        tableView.addTableColumn(column)
        tableView.autoresizesSubviews = true
        tableView.wantsLayer = true
        tableView.layer?.cornerRadius = 6
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.gridStyleMask = NSTableViewGridLineStyle.init(rawValue: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = NSColor.clear

        settingsView.isHidden = true
        settingsView.searchCallback = { [weak self] searchString in
            guard let selfie = self else { return }

            if searchString.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                selfie.filteredServices = selfie.allServices
            } else {
                // Can't filter array with NSPredicate without making Service inherit KVO from NSObject, therefore we create
                // an array of service names that we can run the predicate on
                let allServiceNames = selfie.allServices.map { $0.name } as NSArray
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", argumentArray: ["*\(searchString)*"])
                guard let filteredServiceNames = allServiceNames.filtered(using: predicate) as? [String] else { return }

                selfie.filteredServices = selfie.allServices.filter { filteredServiceNames.contains($0.name) }
            }

            selfie.tableView.reloadData()
        }

        contentView.addSubview(settingsView)
        settingsView.snp.makeConstraints { make in
            make.top.left.right.equalTo(0)
            make.height.equalTo(130)
        }
    }

    func willShow() {
        self.selectionChanged = false

        scrollView.topConstraint?.update(offset: settingsView.frame.size.height)
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
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? "identifier"
        let cell = tableView.make(withIdentifier: identifier, owner: self) ?? EditorTableCell()

        guard let view = cell as? EditorTableCell else { return nil }

        let service = filteredServices[row]
        view.textField?.stringValue = service.name
        view.selected = selectedServices.contains(service)
        view.toggleCallback = { [weak self] in
            guard let selfie = self else { return }

            selfie.selectionChanged = true

            if view.selected {
                self?.selectedServices.append(service)
            } else {
                if let index = self?.selectedServices.index(of: service) {
                    self?.selectedServices.remove(at: index)
                }
            }

            Preferences.shared.selectedServices = selfie.selectedServices
        }

        return view
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let cell = tableView.make(withIdentifier: "rowView", owner: self) ?? ServiceTableRowView()

        guard let view = cell as? ServiceTableRowView else { return nil }

        view.showSeparator = row + 1 < filteredServices.count

        return view
    }
}
