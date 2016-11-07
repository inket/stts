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

    var services: [Service]

    init(services: [Service]) {
        self.services = services

        super.init()
        setup()
    }

    private func setup() {
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
        let column = NSTableColumn(identifier: "ident")
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
        var frame = scrollView.frame
        frame.size.height = tableView.intrinsicContentSize.height
        scrollView.frame = frame

        frame = contentView.frame
        frame.size.height = scrollView.frame.size.height + bottomBar.frame.size.height
        contentView.frame = frame
    }

    public func reloadData(at index: Int? = nil) {
        services.sort()

        guard index != nil else {
            tableView.reloadData()
            return
        }

        tableView.reloadData(forRowIndexes: IndexSet(integer: index!), columnIndexes: IndexSet(integer: 0))
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
        let cell = tableView.make(withIdentifier: "rowView", owner: self) ?? CustomRowView()

        guard let view = cell as? CustomRowView else { return nil }

        view.showSeparator = row + 1 < services.count

        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        NSWorkspace.shared().open(services[row].url)
        return false
    }
}
