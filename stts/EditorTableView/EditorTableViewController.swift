//
//  EditorTableViewController.swift
//  stts
//

import Cocoa

class EditorTableViewController: NSObject, SwitchableTableViewController {
    let contentView: NSStackView
    let scrollView: CustomScrollView
    let bottomBar: BottomBar
    let tableView = NSTableView()

    let allServices: [BaseService] = BaseService.all().sorted()
    let allServicesWithoutSubServices: [BaseService] = BaseService.allWithoutSubServices().sorted()
    var filteredServices: [BaseService]
    var selectedServices: [BaseService] = Preferences.shared.selectedServices

    var selectionChanged = false

    let settingsView = SettingsView()

    var hidden: Bool = true

    var savedScrollPosition: CGPoint = .zero

    var selectedCategory: ServiceCategory? {
        didSet {
            // Save the scroll position between screens
            let scrollToPosition: CGPoint?

            if selectedCategory != nil && oldValue == nil {
                savedScrollPosition = CGPoint(x: 0, y: tableView.visibleRect.minY)
                scrollToPosition = .zero
            } else if selectedCategory == nil && oldValue != nil {
                scrollToPosition = savedScrollPosition
            } else {
                scrollToPosition = nil
            }

            // Adjust UI
            bottomBar.openedCategory(selectedCategory, backCallback: { [weak self] in
                self?.selectedCategory = nil
            })

            guard let category = selectedCategory else {
                // Show the unfiltered services
                filteredServices = allServicesWithoutSubServices
                tableView.reloadData()

                if let scrollPosition = scrollToPosition {
                    tableView.scroll(scrollPosition)
                }

                return
            }

            // Find the sub services
            var subServices = allServices.filter {
                // Can't check superclass matches without mirror
                Mirror(reflecting: $0).superclassMirror?.subjectType == category.subServiceSuperclass

                // Exclude the category so that we can add it at the top
                && $0 != category as? BaseService
            }.sorted()

            // Add the category as the top item
            (category as? BaseService).flatMap { subServices.insert($0, at: 0) }

            filteredServices = subServices
            tableView.reloadData()

            if let scrollPosition = scrollToPosition {
                tableView.scroll(scrollPosition)
            }
        }
    }

    var isSearching: Bool {
        settingsView.searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) != ""
    }

    private var maxNameWidth: CGFloat? {
        didSet {
            if oldValue != maxNameWidth {
                tableView.tile()
            }
        }
    }

    init(contentView: NSStackView, scrollView: CustomScrollView, bottomBar: BottomBar) {
        self.contentView = contentView
        self.scrollView = scrollView
        self.filteredServices = allServicesWithoutSubServices
        self.bottomBar = bottomBar

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
        if #available(OSX 11.0, *) {
            tableView.style = .fullWidth
        }

        settingsView.isHidden = true
        settingsView.searchCallback = { [weak self] searchString in
            guard
                let strongSelf = self,
                let allServices = strongSelf.allServices as? [Service],
                let allServicesWithoutSubServices = strongSelf.allServicesWithoutSubServices as? [Service]
            else { return }

            if searchString.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                strongSelf.filteredServices = allServicesWithoutSubServices
            } else {
                // Can't filter array with NSPredicate without making Service inherit KVO from NSObject, therefore we create
                // an array of service names that we can run the predicate on
                let allServiceNames = allServices.compactMap { $0.name } as NSArray
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", argumentArray: ["*\(searchString)*"])
                guard let filteredServiceNames = allServiceNames.filtered(using: predicate) as? [String] else { return }

                strongSelf.filteredServices = allServices.filter { filteredServiceNames.contains($0.name) }
            }

            if strongSelf.selectedCategory != nil {
                strongSelf.selectedCategory = nil
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

    @objc func deselectCategory() {
        selectedCategory = nil
    }
}

extension EditorTableViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredServices.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow != -1 else { return }

        // We're only interested in selections of categories
        guard
            selectedCategory == nil,
            let category = filteredServices[tableView.selectedRow] as? ServiceCategory
        else { return }

        // Change the selected category
        selectedCategory = category
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

        if isSearching || selectedCategory != nil {
            view.type = .service
        } else {
            view.type = (service is ServiceCategory) ? .category : .service
        }

        switch view.type {
        case .service:
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
        case .category:
            view.textField?.stringValue = (service as? ServiceCategory)?.categoryName ?? service.name
            view.selected = false
            view.toggleCallback = {}
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
