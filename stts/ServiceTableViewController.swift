//
//  ServiceTableViewController.swift
//  stts
//
//  Created by inket on 2/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa
import SnapKit

class ServiceTableViewController: NSObject {
    let contentView = NSStackView(frame: CGRect(x: 0, y: 0, width: 180, height: 400))
    let scrollView = CustomScrollView()
    let tableView = NSTableView()
    let bottomBar = BottomBar()

    let editorTableViewController: EditorTableViewController

    var services: [Service] = Preferences.shared.selectedServices
    var servicesBeingUpdated = [Service]()
    var generalStatus: ServiceStatus {
        let badServices = services.filter { $0.status != .good && $0.status != .undetermined }
        if badServices.count > 0 {
            return .major
        } else {
            return .good
        }
    }

    var updateCallback: (() -> ())?

    override init() {
        self.editorTableViewController = EditorTableViewController(scrollView: scrollView)
        super.init()
    }

    func setup() {
        bottomBar.openSettingsCallback = { [weak self] in
            self?.editorTableViewController.showTableView()
            self?.resizeViews()
        }

        bottomBar.closeSettingsCallback = { [weak self] in
            guard let selfie = self else { return }

            self?.scrollView.documentView = self?.tableView

            if selfie.editorTableViewController.selectionChanged {
                self?.reloadServices()
                self?.reloadData()
            }

            self?.resizeViews()
        }

        contentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.width.greaterThanOrEqualTo(180)
            make.height.greaterThanOrEqualTo(100)
        }

        contentView.addSubview(scrollView)
        contentView.addSubview(bottomBar)

        scrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalTo(0)
        }

        bottomBar.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.top.equalTo(scrollView.snp.bottom)
            make.height.equalTo(30)
            make.left.right.equalTo(0)
            make.bottom.equalTo(0)
        }

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizesSubviews = true
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6

        tableView.frame = scrollView.bounds
        let column = NSTableColumn(identifier: "serviceColumnIdentifier")
        column.width = tableView.frame.size.width
        tableView.addTableColumn(column)
        tableView.autoresizesSubviews = true
        tableView.wantsLayer = true
        tableView.layer?.cornerRadius = 6
        tableView.headerView = nil
        tableView.rowHeight = 40
        tableView.gridColor = NSColor.green
        tableView.gridStyleMask = NSTableViewGridLineStyle.init(rawValue: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
    }

    public func resizeViews() {
        guard let currentTableView = scrollView.documentView as? NSTableView else { return }

        let maxHeight: CGFloat = currentTableView == tableView ? 490 : 300

        var frame = scrollView.frame
        frame.size.height = min(currentTableView.intrinsicContentSize.height, maxHeight)
        scrollView.frame = frame

        // Ugly, but oh well.
        (NSApp.delegate as? AppDelegate)?.popupController.resizePopup(
            to: CGSize(width: contentView.frame.width,
                       height: scrollView.frame.size.height + bottomBar.frame.size.height)
        )
    }

    func reloadServices() {
        self.services = Preferences.shared.selectedServices
        self.servicesBeingUpdated = [Service]()

        // Ugly again...
        (NSApp.delegate as? AppDelegate)?.updateServices()
    }

    public func reloadData(at index: Int? = nil) {
        services.sort()

        guard index != nil else {
            tableView.reloadData()
            return
        }

        tableView.reloadData(forRowIndexes: IndexSet(integer: index!), columnIndexes: IndexSet(integer: 0))
    }

    func updateServices(updateCallback: @escaping () -> ()) {
        self.updateCallback = updateCallback

        let serviceCallback: ((Service) -> ()) = { [weak self] service in self?.updatedStatus(for: service) }

        bottomBar.status = .updating

        services.forEach {
            servicesBeingUpdated.append($0)
            $0.updateStatus(callback: serviceCallback)
        }
    }

    func updatedStatus(for service: Service) {
        if let index = servicesBeingUpdated.index(of: service) {
            servicesBeingUpdated.remove(at: index)
        }

        DispatchQueue.main.async { [weak self] in
            self?.reloadData()

            if self?.servicesBeingUpdated.count == 0 {
                self?.bottomBar.status = .updated(Date())

                self?.updateCallback?()
                self?.updateCallback = nil
            }
        }
    }
}

extension ServiceTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return services.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nil
    }
}

extension ServiceTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? "identifier"
        let cell = tableView.make(withIdentifier: identifier, owner: self) ?? StatusTableCell()

        guard let view = cell as? StatusTableCell else { return nil }

        let service = services[row]
        view.textField?.stringValue = service.name
        view.statusField.stringValue = service.message
        view.statusIndicator.status = service.status

        return view
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let cell = tableView.make(withIdentifier: "rowView", owner: self) ?? ServiceTableRowView()

        guard let view = cell as? ServiceTableRowView else { return nil }

        view.showSeparator = row + 1 < services.count

        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        NSWorkspace.shared().open(services[row].url)
        return false
    }
}
