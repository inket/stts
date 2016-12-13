//
//  EditorTableViewController.swift
//  stts
//

import Cocoa
import SnapKit

class EditorTableViewController: NSObject {
    let contentView: NSStackView
    let scrollView: CustomScrollView
    let tableView = NSTableView()

    var allServices: [Service] = Service.all().sorted()
    var selectedServices: [Service] = Preferences.shared.selectedServices

    var selectionChanged = false

    let settingsView = SettingsView()

    var hidden: Bool {
        return settingsView.isHidden
    }

    init(contentView: NSStackView, scrollView: CustomScrollView) {
        self.contentView = contentView
        self.scrollView = scrollView

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

        contentView.addSubview(settingsView)
        settingsView.snp.makeConstraints { make in
            make.top.left.right.equalTo(0)
            make.height.equalTo(100)
        }
    }

    func show() {
        self.selectionChanged = false

        scrollView.topConstraint?.update(offset: 100)
        scrollView.documentView = tableView

        settingsView.isHidden = false

        resizeViews()
    }

    func resizeViews() {
        tableView.frame = scrollView.bounds
        tableView.tableColumns.first?.width = tableView.frame.size.width

        var frame = scrollView.frame
        frame.size.height = min(tableView.intrinsicContentSize.height, 360)
        scrollView.frame = frame

        (NSApp.delegate as? AppDelegate)?.popupController.resizePopup(
            width: 220,
            height: scrollView.frame.size.height + 30 // bottomBar.frame.size.height
        )
    }

    func willOpenPopup() {
        resizeViews()
    }

    func hide() {
        settingsView.isHidden = true
    }
}

extension EditorTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return allServices.count
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

        let service = allServices[row]
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

        view.showSeparator = row + 1 < allServices.count

        return view
    }
}
