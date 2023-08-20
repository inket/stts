//
//  PreferencesServicesView.swift
//  stts
//

import Cocoa
import PreferencesWindow
import Combine

final class PreferencesServicesView: NSView {
    private enum Filter: Int, CaseIterable {
        case availableServices = 0
        case enabledServices = 1

        var title: String {
            switch self {
            case .availableServices:
                return "Available"
            case .enabledServices:
                return "Enabled"
            }
        }
    }

    private let box = NSBox()
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    private let serviceLoader: ServiceLoader
    private let preferences: Preferences
    private var filteredServices: [ServiceDefinition]
    private var selectedServices: [ServiceDefinition]

    private var selectionChanged = false

    private var savedScrollPosition: CGPoint = .zero

    private let searchField = NSSearchField()
    private lazy var filterSegmentedControl: NSSegmentedControl = {
        NSSegmentedControl(
            labels: Filter.allCases.map { $0.title },
            trackingMode: .selectOne,
            target: self,
            action: #selector(updatedFilter)
        )
    }()

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

            guard
                let categoryDefinition = selectedCategory,
                let serviceCategory = categoryDefinition.build() as? ServiceCategory
            else {
                // Show the unfiltered services
                filterServices()

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

                let mirror = Mirror(reflecting: service)

                // TODO: Check ServiceDefinition type instead
                let hasExpectedClass =
                    mirror.subjectType == serviceCategory.subServiceSuperclass ||
                    mirror.superclassMirror?.subjectType == serviceCategory.subServiceSuperclass

                // Exclude the category so that we can add it at the top
                let isTheCategory = service is ServiceCategory

                return hasExpectedClass && !isTheCategory
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
        searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) != ""
    }

    var isFiltering: Bool {
        switch Filter(rawValue: filterSegmentedControl.selectedSegment) {
        case .availableServices, .none:
            return false
        case .enabledServices:
            return true
        }
    }

    init(
        serviceLoader: ServiceLoader,
        preferences: Preferences
    ) {
        self.serviceLoader = serviceLoader
        self.preferences = preferences

        filteredServices = serviceLoader.allServicesWithoutSubServices
        selectedServices = preferences.selectedServices

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.action = #selector(updatedSearchString)
        searchField.target = self
        addSubview(searchField)

        filterSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        filterSegmentedControl.selectedSegment = 0
        addSubview(filterSegmentedControl)

        box.translatesAutoresizingMaskIntoConstraints = false
        box.titlePosition = .noTitle
        box.contentView = scrollView
        box.contentViewMargins = NSSize(width: 0, height: 0)
        addSubview(box)

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizesSubviews = true
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.backgroundColor = .clear

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "editorColumnIdentifier"))
        column.width = 200
        tableView.addTableColumn(column)
        tableView.autoresizesSubviews = true
        tableView.headerView = nil
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.dataSource = self
        tableView.delegate = self
//        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = NSColor.clear
        tableView.style = .fullWidth

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 600),
            widthAnchor.constraint(equalToConstant: 400),

            searchField.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            filterSegmentedControl.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            filterSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            filterSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            box.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor, constant: 12),
            box.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            box.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            box.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

//            scrollView.topAnchor.constraint(equalTo: box.topAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
//            scrollView.trailingAnchor.constraint(equalTo: box.trailingAnchor),
//            scrollView.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
    }

    func deselectCategory() {
        selectedCategory = nil
    }

    @objc private func updatedSearchString() {
        deselectCategory()
        filterServices()
    }

    @objc private func updatedFilter() {
        deselectCategory()
        filterServices()
    }

    private func filterServices() {
        let searchString = searchField.stringValue
        var source: [ServiceDefinition]

        switch Filter(rawValue: filterSegmentedControl.selectedSegment) {
        case .availableServices, .none:
            if isSearching {
                source = serviceLoader.allServices
            } else {
                source = serviceLoader.allServicesWithoutSubServices
            }
        case .enabledServices:
            source = serviceLoader.allServices.filter {
                selectedServices.contains(where: $0.eq)
            }
        }

        if isSearching {
            // Can't filter array with NSPredicate without making Service inherit KVO from NSObject, therefore
            // we create an array of service names that we can run the predicate on
            let allServiceNames = source.compactMap { $0.name } as NSArray
            let predicate = NSPredicate(format: "SELF LIKE[cd] %@", argumentArray: ["*\(searchString)*"])
            guard let filteredServiceNames = allServiceNames.filtered(using: predicate) as? [String] else { return }

            let filteredServiceNamesSet = Set<String>(filteredServiceNames)
            filteredServices = source.filter { filteredServiceNamesSet.contains($0.name) }
        } else {
            filteredServices = source
        }

        if selectedCategory != nil {
            selectedCategory = nil
        }

        tableView.reloadData()
    }
}

extension PreferencesServicesView: PreferencesView {
    func willShow() {
        selectedCategory = nil
    }
}

extension PreferencesServicesView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if selectedCategory == nil {
            return filteredServices.count
        } else {
            return filteredServices.count + 1
        }
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow != -1 else { return }

        let realSelectedRow = selectedCategory == nil ? tableView.selectedRow : max(tableView.selectedRow - 1, 0)
        let selectedServiceDefinition = filteredServices[realSelectedRow]
        // We're only interested in selections of categories
        if selectedServiceDefinition.isCategory == true {
            // Change the selected category
            selectedCategory = selectedServiceDefinition
        }
    }
}

extension PreferencesServicesView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 38
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier(rawValue: "identifier")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) ?? EditorTableCell()

        guard let view = cell as? EditorTableCell else { return nil }

        let isBackRow = selectedCategory != nil && row == 0
        let serviceRow = selectedCategory == nil ? row : max(row - 1, 0)
        let serviceDefinition = filteredServices[serviceRow]

        if isBackRow {
            view.type = .back
        } else if isSearching || isFiltering || selectedCategory != nil {
            view.type = .service
        } else {
            view.type = (serviceDefinition.isCategory == true) ? .category : .service
        }

        switch view.type {
        case .none:
            view.textField?.stringValue = ""
            view.selected = false
            view.toggleCallback = {}
            view.backCallback = {}
        case .back:
            if let selectedCategory {
                guard let categoryService = selectedCategory.build() as? ServiceCategory else {
                    assertionFailure("Expected to build category service without issues")
                    return nil
                }

                view.textField?.stringValue = categoryService.categoryName
            } else {
                view.textField?.stringValue = ""
            }

            view.selected = false
            view.toggleCallback = {}
            view.backCallback = { [weak self] in self?.deselectCategory() }
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
            view.backCallback = {}
        case .category:
            guard let categoryService = serviceDefinition.build() as? ServiceCategory else {
                assertionFailure("Expected to build category service without issues")
                return nil
            }

            view.textField?.stringValue = categoryService.categoryName
            view.selected = false
            view.toggleCallback = {}
            view.backCallback = {}
        }

        if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ServiceTableRowView {
            rowView.usesWindowBackground = view.type == .back
            rowView.selectionHighlightStyle = view.type == .category ? .regular : .none
        }

        return view
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "rowView")
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) ?? ServiceTableRowView()

        guard let view = cell as? ServiceTableRowView else { return nil }

        view.showSeparator = false

        return view
    }
}
