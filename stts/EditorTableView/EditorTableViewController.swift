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

    let serviceLoader: ServiceLoader
    let preferences: Preferences
    var filteredServices: [ServiceDefinition]
    var selectedServices: [ServiceDefinition]

    var selectionChanged = false

    let settingsView: SettingsView

    var hidden: Bool = true

    var savedScrollPosition: CGPoint = .zero

    var selectedCategory: ServiceDefinition? {
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

            guard
                let categoryDefinition = selectedCategory,
                let serviceCategory = categoryDefinition.build() as? ServiceCategory
            else {
                // Show the unfiltered services
                filteredServices = serviceLoader.allServicesWithoutSubServices
                tableView.reloadData()

                if let scrollPosition = scrollToPosition {
                    tableView.scroll(scrollPosition)
                }

                return
            }

            // Find the sub services
            var subServices = serviceLoader.allServices.filter { serviceDefinition in
                guard
                    serviceDefinition.isSubService == true,
                    let service = serviceDefinition.build()
                else { return false }

                // Can't check superclass matches without mirror
                let hasExpectedSuperclass =
                    Mirror(reflecting: service).superclassMirror?.subjectType == serviceCategory.subServiceSuperclass

                // Exclude the category so that we can add it at the top
                let isTheCategory = service is ServiceCategory

                return hasExpectedSuperclass && !isTheCategory
            }.sorted(by: ServiceDefinitionSortByName)

            // Add the category as the top item
            subServices.insert(categoryDefinition, at: 0)

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

    private var cachedTableViewWidth: CGFloat = 0
    private var cachedMaxNameWidth: CGFloat?
    private var maxNameWidth: CGFloat? {
        if cachedTableViewWidth != tableView.frame.width || cachedMaxNameWidth == nil {
            cachedTableViewWidth = tableView.frame.width
            cachedMaxNameWidth = EditorTableCell.maxNameWidth(for: tableView)
            return cachedMaxNameWidth!
        }

        return cachedMaxNameWidth
    }

    init(
        contentView: NSStackView,
        scrollView: CustomScrollView,
        bottomBar: BottomBar,
        serviceLoader: ServiceLoader,
        preferences: Preferences
    ) {
        self.contentView = contentView
        self.scrollView = scrollView
        self.bottomBar = bottomBar

        self.serviceLoader = serviceLoader
        self.preferences = preferences

        filteredServices = serviceLoader.allServicesWithoutSubServices
        selectedServices = preferences.selectedServices

        settingsView = SettingsView(preferences: preferences)

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
            guard let self else { return }

            if searchString.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
                self.filteredServices = serviceLoader.allServicesWithoutSubServices
            } else {
                // Can't filter array with NSPredicate without making Service inherit KVO from NSObject, therefore
                // we create an array of service names that we can run the predicate on
                let allServiceNames = serviceLoader.allServices.compactMap { $0.name } as NSArray
                let predicate = NSPredicate(format: "SELF LIKE[cd] %@", argumentArray: ["*\(searchString)*"])
                guard let filteredServiceNames = allServiceNames.filtered(using: predicate) as? [String] else { return }

                let filteredServiceNamesSet = Set<String>(filteredServiceNames)
                self.filteredServices = serviceLoader.allServices.filter { filteredServiceNamesSet.contains($0.name) }
            }

            if self.selectedCategory != nil {
                self.selectedCategory = nil
            }

            self.tableView.reloadData()
        }

        settingsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(settingsView)

        NSLayoutConstraint.activate([
            settingsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            settingsView.topAnchor.constraint(equalTo: contentView.topAnchor),
            settingsView.heightAnchor.constraint(equalToConstant: 170)
        ])
    }

    func willShow() {
        self.selectionChanged = false

        scrollView.topConstraint?.constant = settingsView.frame.size.height
        scrollView.documentView = tableView

        settingsView.isHidden = false

        // We should be using NSWindow's makeFirstResponder: instead of the search field's selectText:,
        // but in this case, makeFirstResponder is causing a bug where the search field "gets focused" twice
        // (focus ring animation) the first time it's drawn.
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
        guard
            tableView.selectedRow != -1,
            selectedCategory == nil
        else { return }

        let selectedServiceDefinition = filteredServices[tableView.selectedRow]
        // We're only interested in selections of categories
        if selectedServiceDefinition.isCategory == true {
            // Change the selected category
            selectedCategory = selectedServiceDefinition
        }
    }
}

extension EditorTableViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let maxNameWidth = maxNameWidth else {
            return EditorTableCell.defaultHeight
        }

        let service = filteredServices[row]

        return EditorTableCell.estimatedHeight(for: service, maxWidth: maxNameWidth)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier(rawValue: "identifier")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) ?? EditorTableCell()

        guard let view = cell as? EditorTableCell else { return nil }

        let serviceDefinition = filteredServices[row]

        if isSearching || selectedCategory != nil {
            view.type = .service
        } else {
            view.type = (serviceDefinition.isCategory == true) ? .category : .service
        }

        switch view.type {
        case .service:
            view.textField?.stringValue = serviceDefinition.name
            view.selected = selectedServices.contains(where: serviceDefinition.eq)
            view.toggleCallback = { [weak self] in
                guard let self else { return }

                selectionChanged = true

                if view.selected {
                    selectedServices.append(serviceDefinition)
                } else {
                    if let index = selectedServices.firstIndex(where: serviceDefinition.eq) {
                        selectedServices.remove(at: index)
                    }
                }

                preferences.selectedServices = selectedServices
            }
        case .category:
            guard let categoryService = serviceDefinition.build() as? ServiceCategory else {
                assertionFailure("Expected to build category service without issues")
                return nil
            }

            view.textField?.stringValue = categoryService.categoryName
            view.selected = false
            view.toggleCallback = {}
        }

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
