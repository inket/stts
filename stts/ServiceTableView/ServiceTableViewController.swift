//
//  ServiceTableViewController.swift
//  stts
//

import Cocoa
import MBPopup

class ServiceTableViewController: NSObject, SwitchableTableViewController {
    let contentView = NSStackView(frame: CGRect(x: 0, y: 0, width: 240, height: 400))
    let scrollView = CustomScrollView()
    let tableView = NSTableView()
    let bottomBar = BottomBar()
    let addServicesNoticeField = NSTextField()

    var editorTableViewController: EditorTableViewController

    var services: [BaseService] = Preferences.shared.selectedServices {
        didSet {
            addServicesNoticeField.isHidden = services.count > 0
        }
    }

    var servicesBeingUpdated = [BaseService]()
    var generalStatus: ServiceStatus {
        let hasBadServices = services.first { $0.status > .maintenance } != nil

        return hasBadServices ? .major : .good
    }

    var hidden: Bool = false

    var updateCallback: (() -> Void)?

    override init() {
        self.editorTableViewController = EditorTableViewController(
            contentView: contentView,
            scrollView: scrollView,
            bottomBar: bottomBar
        )

        super.init()
    }

    func setup() {
        bottomBar.reloadServicesCallback = (NSApp.delegate as? AppDelegate)!.updateServices

        bottomBar.openSettingsCallback = { [weak self] in
            self?.hide()
            self?.editorTableViewController.show()
        }

        bottomBar.closeSettingsCallback = { [weak self] in
            self?.editorTableViewController.hide()
            self?.show()
        }

        guard let superview = contentView.superview else {
            assertionFailure("Add contentView to another view before calling setup()")
            return
        }

        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),

            // tableView.rowHeight + bottomBar.frame.size.height + 2
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40 + 30 + 2)
        ])

        [scrollView, bottomBar, addServicesNoticeField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: contentView.topAnchor)
        scrollView.topConstraint = scrollViewTopConstraint

        NSLayoutConstraint.activate([
            scrollViewTopConstraint,
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBar.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 30),

            addServicesNoticeField.heightAnchor.constraint(equalToConstant: 22),
            addServicesNoticeField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            addServicesNoticeField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            addServicesNoticeField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -14)
        ])

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizesSubviews = true
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6

        tableView.frame = scrollView.bounds
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "serviceColumnIdentifier"))
        column.width = tableView.frame.size.width
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
        if #available(OSX 11.0, *) {
            tableView.style = .fullWidth
        }

        addServicesNoticeField.isEditable = false
        addServicesNoticeField.isBordered = false
        addServicesNoticeField.isSelectable = false

        let italicFont = NSFontManager.shared.font(
            withFamily: NSFont.systemFont(ofSize: 13).fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: 13
        )

        addServicesNoticeField.font = italicFont
        addServicesNoticeField.textColor = NSColor.textColor
        addServicesNoticeField.maximumNumberOfLines = 1
        addServicesNoticeField.cell!.truncatesLastVisibleLine = true
        addServicesNoticeField.alignment = .center
        addServicesNoticeField.stringValue = "Maybe enable some services? :)"
        addServicesNoticeField.backgroundColor = .clear
    }

    func willOpenPopup() {
        resizeViews()
        reloadData()

        if case let .updated(date) = bottomBar.status {
            if Date().timeIntervalSince1970 - date.timeIntervalSince1970 > 60 {
                (NSApp.delegate as? AppDelegate)?.updateServices()
            }
        }
    }

    func willShow() {
        scrollView.topConstraint?.constant = 0
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

    func willHide() {
        addServicesNoticeField.isHidden = true
    }

    func resizeViews() {
        var frame = scrollView.frame
        frame.size.height = min(tableView.intrinsicContentSize.height, 490)
        scrollView.frame = frame

        (NSApp.delegate as? AppDelegate)?.popupController.resizePopup(height: scrollView.frame.size.height + bottomBar.frame.size.height)
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

            // Avoid issues with relative time marking it as "in a few seconds"
            let oneSecondInThePastDate = Date(timeInterval: -1, since: Date())
            bottomBar.status = .updated(oneSecondInThePastDate)

            self.updateCallback?()
            self.updateCallback = nil

            resizeViews()

            return
        }

        self.updateCallback = updateCallback
        let serviceCallback: ((BaseService) -> Void) = { [weak self] service in self?.updatedStatus(for: service) }

        bottomBar.status = .updating

        services.forEach {
            servicesBeingUpdated.append($0)
            $0.updateStatus(callback: serviceCallback)
        }
    }

    func updatedStatus(for service: BaseService) {
        if let index = servicesBeingUpdated.firstIndex(of: service) {
            servicesBeingUpdated.remove(at: index)
        }

        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
            self?.resizeViews()

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
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier(rawValue: "identifier")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) ?? StatusTableCell()

        guard let view = cell as? StatusTableCell else { return nil }
        guard let service = services[row] as? Service else { return nil }

        view.textField?.stringValue = service.name
        view.statusField.stringValue = service.message
        view.statusIndicator.status = service.status

        return view
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "rowView")
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) ?? ServiceTableRowView()

        guard let view = cell as? ServiceTableRowView else { return nil }

        view.showSeparator = row + 1 < services.count

        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let service = services[row] as? Service else { return false }

        NSWorkspace.shared.open(service.url)
        return false
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let service = services[row] as? Service else { return 40 }

        return StatusTableCell.Layout.heightOfRow(
            withMessage: service.message,
            width: tableView.frame.size.width - 3 // tableview padding is 3
        )
    }
}
