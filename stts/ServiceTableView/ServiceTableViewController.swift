//
//  ServiceTableViewController.swift
//  stts
//

import Cocoa
import SnapKit
import MBPopup

class ServiceTableViewController: NSObject {
    let contentView = NSStackView(frame: CGRect(x: 0, y: 0, width: 190, height: 400))
    let scrollView = CustomScrollView()
    let tableView = NSTableView()
    let bottomBar = BottomBar()
    let addServicesNoticeField = NSTextField()

    let editorTableViewController: EditorTableViewController

    var services: [Service] = Preferences.shared.selectedServices {
        didSet {
            addServicesNoticeField.isHidden = services.count > 0
        }
    }

    var servicesBeingUpdated = [Service]()
    var generalStatus: ServiceStatus {
        let badServices = services.filter {
            $0.status != .good && $0.status != .maintenance && $0.status != .undetermined
        }

        if badServices.count > 0 {
            return .major
        } else {
            return .good
        }
    }

    var updateCallback: (() -> Void)?

    override init() {
        self.editorTableViewController = EditorTableViewController(contentView: contentView, scrollView: scrollView)
        super.init()
    }

    func setup() {
        bottomBar.reloadServicesCallback = (NSApp.delegate as? AppDelegate)!.updateServices

        bottomBar.openSettingsCallback = { [weak self] in
            self?.addServicesNoticeField.isHidden = true
            self?.editorTableViewController.show()
        }

        bottomBar.closeSettingsCallback = { [weak self] in
            self?.editorTableViewController.hide()
            self?.show()
        }

        contentView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(0)
            make.width.greaterThanOrEqualTo(190)
            make.height.greaterThanOrEqualTo(40 + 30 + 2) // tableView.rowHeight + bottomBar.frame.size.height + 2
        }

        contentView.addSubview(scrollView)
        contentView.addSubview(bottomBar)

        scrollView.snp.makeConstraints { make in
            scrollView.topConstraint = make.top.equalToSuperview().constraint
            make.left.right.equalTo(0)
        }

        bottomBar.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.top.equalTo(scrollView.snp.bottom)
            make.height.equalTo(30)
            make.left.right.equalTo(0)
            make.bottom.equalTo(0)
        }

        contentView.addSubview(addServicesNoticeField)
        addServicesNoticeField.snp.makeConstraints { make in
            make.height.equalTo(22)
            make.left.right.equalTo(0)
            make.centerY.equalToSuperview().offset(-10)
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
        tableView.gridStyleMask = NSTableViewGridLineStyle.init(rawValue: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = NSColor.clear

        addServicesNoticeField.isEditable = false
        addServicesNoticeField.isBordered = false
        addServicesNoticeField.isSelectable = false
        let italicFont = NSFontManager.shared().font(withFamily: NSFont.systemFont(ofSize: 10).fontName,
                                                     traits: NSFontTraitMask.italicFontMask,
                                                     weight: 5,
                                                     size: 10)
        addServicesNoticeField.font = italicFont
        addServicesNoticeField.textColor = NSColor(calibratedWhite: 0, alpha: 0.5)
        addServicesNoticeField.maximumNumberOfLines = 1
        addServicesNoticeField.cell!.truncatesLastVisibleLine = true
        addServicesNoticeField.alignment = .center
        addServicesNoticeField.stringValue = "Maybe add some services? :)"
    }

    func willOpenPopup() {
        if !editorTableViewController.hidden {
            editorTableViewController.willOpenPopup()
            return
        }

        resizeViews()
        reloadData()

        if case let .updated(date) = bottomBar.status {
            if Date().timeIntervalSince1970 - date.timeIntervalSince1970 > 60 {
                (NSApp.delegate as? AppDelegate)?.updateServices()
            }
        }
    }

    func show() {
        scrollView.topConstraint?.update(offset: 0)
        scrollView.documentView = tableView

        if editorTableViewController.selectionChanged {
            self.services = Preferences.shared.selectedServices
            reloadData()

            (NSApp.delegate as? AppDelegate)?.updateServices()
        } else {
            addServicesNoticeField.isHidden = services.count > 0
        }

        resizeViews()
    }

    func resizeViews() {
        var frame = scrollView.frame
        frame.size.height = min(tableView.intrinsicContentSize.height, 490)
        scrollView.frame = frame

        (NSApp.delegate as? AppDelegate)?.popupController.resizePopup(
            width: 190,
            height: scrollView.frame.size.height + bottomBar.frame.size.height
        )
    }

    func reloadData(at index: Int? = nil) {
        services.sort()

        bottomBar.updateStatusText()

        guard index != nil else {
            tableView.reloadData()
            return
        }

        tableView.reloadData(forRowIndexes: IndexSet(integer: index!), columnIndexes: IndexSet(integer: 0))
    }

    func updateServices(updateCallback: @escaping () -> Void) {
        self.servicesBeingUpdated = [Service]()

        guard services.count > 0 else {
            reloadData()
            bottomBar.status = .updated(Date())

            self.updateCallback?()
            self.updateCallback = nil

            return
        }

        self.updateCallback = updateCallback
        let serviceCallback: ((Service) -> Void) = { [weak self] service in self?.updatedStatus(for: service) }

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
