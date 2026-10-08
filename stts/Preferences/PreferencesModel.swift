//
//  PreferencesModel.swift
//  stts
//

import PreferencesWindow
import SwiftUI

/// The state behind the settings window, shared by all four panes.
///
/// `Preferences` is the store of record — everything here writes straight through to it, since the
/// window has no Save button. What this adds is the shape the views need: the enabled set as a
/// `Set` rather than an array of definitions, the flattened service list, and the `@Published`
/// signal that makes SwiftUI redraw when any of it changes.
@MainActor
final class PreferencesModel: ObservableObject {
    /// A pane, and its row in the sidebar.
    enum Pane: String, CaseIterable, Identifiable, Hashable {
        case general
        case services
        case customServices
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .services: return "Services"
            case .customServices: return "Custom services"
            case .about: return "About"
            }
        }

        var glyph: PreferencesGlyph {
            switch self {
            case .general: return .general
            case .services: return .services
            case .customServices: return .customServices
            case .about: return .about
            }
        }

        /// Fixed colours rather than `PopupLayout`'s dynamic dark/light ones — each pane keeps one
        /// hue in both appearances, the way System Settings' own tiles don't relight for dark mode.
        var tint: Color {
            switch self {
            case .general: return NSColor(designHex: 0x2B6491).swiftUI
            case .services: return NSColor(designHex: 0x1F6B43).swiftUI
            case .customServices: return NSColor(designHex: 0xC4801F).swiftUI
            case .about: return NSColor(designHex: 0x544C42).swiftUI
            }
        }
    }

    /// One row of the Services pane's filter column — which slice of the catalogue the list shows.
    ///
    /// `all` is the only scope that reaches the whole catalogue; the rest are subsets of what's
    /// enabled, since stts only knows anything about a service it polls.
    enum ServicesFilter: Hashable, CaseIterable {
        case all
        case monitoring
        case notifying
        case affected

        /// The filter column's sections, in order. `nil` is the untitled block at the top.
        static let sections: [(title: String?, filters: [ServicesFilter])] = [
            (nil, [.all]),
            ("Monitored", [.monitoring, .notifying, .affected])
        ]

        var title: String {
            switch self {
            case .all: return "All services"
            case .monitoring: return "Monitoring"
            case .notifying: return "Notifying"
            case .affected: return "Affected"
            }
        }

        var symbolName: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .monitoring: return "checkmark.circle"
            case .notifying: return "bell"
            case .affected: return "exclamationmark.triangle"
            }
        }

        /// What an empty list under this scope says. `all` is never empty.
        var emptyTitle: String {
            switch self {
            case .all: return ""
            case .monitoring: return "Nothing monitored yet"
            case .notifying: return "No notifications turned on"
            case .affected: return "Everything is operational"
            }
        }

        var emptyIllustration: EmptyStateIllustration.Kind {
            self == .affected ? .allClear : .addServices
        }
    }

    let serviceLoader: ServiceLoader
    let preferences: Preferences

    /// Rebuilds the popup's services after the enabled set changes.
    var onSelectionChange: (() -> Void)?
    /// Custom services whose definition changed (edited, or replaced by an import), by identifier.
    var onCustomServiceChange: ((Set<String>) -> Void)?
    /// A new check interval needs `AppDelegate`'s timer restarted.
    var onRefreshIntervalChange: ((Int) -> Void)?

    @Published var selectedPane: Pane = .general
    @Published private(set) var enabledIdentifiers: Set<String> = []
    @Published var expandedGroups: Set<String> = []
    @Published var searchTerm = ""
    @Published var servicesFilter: ServicesFilter = .all

    let customServiceStore: CustomServiceStore
    /// The store's services, republished so the Custom services pane redraws when they change.
    @Published private(set) var customServices: [CustomService] = []
    /// Each custom service's last check, from the popup's services — see `updateStatuses(_:)`.
    @Published private(set) var customResults: [UUID: CustomService.CheckResult] = [:]

    /// The last status the popup reported for each enabled service, by global identifier. This
    /// model polls nothing itself; `AppDelegate` pushes the popup's snapshot through
    /// `updateStatuses(_:)` whenever the popup's own state changes, so "Affected" here is exactly
    /// what the popup is showing.
    @Published private(set) var statuses: [String: ServiceStatus] = [:]

    /// Top-level entries, alphabetically: vendors with sub-services and standalone services alike.
    /// Computed once in `reload()` rather than as a computed property — `allServicesWithoutSubServices`
    /// is already sorted (it's a filter of `ServiceLoader`'s already-sorted `allServices`), so
    /// re-sorting it on every access, from every view that reads it on every SwiftUI diff pass, was
    /// pure waste at catalogue size.
    private(set) var topLevelServices: [ServiceDefinition] = []

    /// Sub-services per category. Populated in bulk by `precomputeReflectionBasedChildren()` for
    /// every category that needs it; `children(of:)` still resolves a `categoryKey`-based category
    /// (a plain property filter, cheap) into this cache lazily on first ask, since there's no
    /// per-category work worth batching there.
    private var childrenCache: [String: [ServiceDefinition]] = [:]

    init(serviceLoader: ServiceLoader, preferences: Preferences, customServiceStore: CustomServiceStore) {
        self.serviceLoader = serviceLoader
        self.preferences = preferences
        self.customServiceStore = customServiceStore
        reload()
    }

    /// The catalogue, without custom services: the Services pane never shows them.
    private var catalogue: [ServiceDefinition] {
        serviceLoader.allServices.filter { !$0.isCustom }
    }

    var totalServiceCount: Int { catalogue.count }
    /// Catalogue services only, for the Services row's badge.
    var enabledCount: Int {
        enabledIdentifiers.filter { !$0.hasPrefix("\(CustomService.providerIdentifier).") }.count
    }

    func reload() {
        enabledIdentifiers = Set(preferences.selectedServices.map(\.globalIdentifier))
        expandedGroups = Set(preferences.expandedServiceGroups)
        customServices = customServiceStore.services
        topLevelServices = serviceLoader.allServicesWithoutSubServices.filter { !$0.isCustom }
        childrenCache.removeAll()
        precomputeReflectionBasedChildren()
    }

    // MARK: - Enabling services

    func isEnabled(_ definition: ServiceDefinition) -> Bool {
        enabledIdentifiers.contains(definition.globalIdentifier)
    }

    func setEnabled(_ isEnabled: Bool, for definitions: [ServiceDefinition]) {
        var selected = preferences.selectedServices

        for definition in definitions {
            let identifier = definition.globalIdentifier
            if isEnabled {
                guard !enabledIdentifiers.contains(identifier) else { continue }
                selected.append(definition)
                enabledIdentifiers.insert(identifier)
            } else {
                selected.removeAll { $0.globalIdentifier == identifier }
                enabledIdentifiers.remove(identifier)
            }
        }

        preferences.selectedServices = selected
        onSelectionChange?()
    }

    /// A binding suitable for a `Toggle`, so a row is one line of SwiftUI.
    func enabledBinding(for definition: ServiceDefinition) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isEnabled(definition) ?? false },
            set: { [weak self] isEnabled in self?.setEnabled(isEnabled, for: [definition]) }
        )
    }

    /// The catalogue services currently being watched, in the order the popup lists them.
    var monitoredServices: [ServiceDefinition] {
        preferences.selectedServices.filter { !$0.isCustom }
    }

    // MARK: - Filters

    func updateStatuses(_ services: [(identifier: String, service: BaseService)]) {
        let latest = Dictionary(services.map { ($0.identifier, $0.service.status) }) { _, last in last }
        if latest != statuses {
            statuses = latest
        }

        let results = Dictionary(
            services.compactMap { pair -> (UUID, CustomService.CheckResult)? in
                guard let service = pair.service as? CustomURLService,
                      let result = service.lastResult else { return nil }
                return (service.definition.id, result)
            }
        ) { _, last in last }
        if results != customResults {
            customResults = results
        }
    }

    /// Monitored services whose effective notification setting isn't `.never` — the override if
    /// one is set, otherwise the General setting.
    var notifyingServices: [ServiceDefinition] {
        monitoredServices.filter {
            preferences.notificationGranularity(forIdentifier: $0.globalIdentifier) != .never
        }
    }

    /// Monitored services with an open incident, by the popup's own definition (`PopupViewModel.
    /// Kind.isIncident`): major, minor or maintenance. Unknown isn't affected — nothing was
    /// reported broken.
    var affectedServices: [ServiceDefinition] {
        monitoredServices.filter { definition in
            switch statuses[definition.globalIdentifier] {
            case .major, .minor, .maintenance: return true
            case .good, .notice, .undetermined, .none: return false
            }
        }
    }

    /// Everything a filter covers, before any search: the flat catalogue for `all` (sub-services
    /// included, so the count matches "Search 543 services"), or that scope's monitored subset.
    func services(for filter: ServicesFilter) -> [ServiceDefinition] {
        switch filter {
        case .all: return catalogue
        case .monitoring: return monitoredServices
        case .notifying: return notifyingServices
        case .affected: return affectedServices
        }
    }

    func count(for filter: ServicesFilter) -> Int {
        services(for: filter).count
    }

    /// The search field's prompt, scoped like the search itself.
    var searchPrompt: String {
        servicesFilter == .all ? "Search \(totalServiceCount) services" : "Search in \(servicesFilter.title)"
    }

    // MARK: - Expansion

    func isExpanded(_ definition: ServiceDefinition) -> Bool {
        expandedGroups.contains(definition.globalIdentifier)
    }

    func toggleExpansion(of definition: ServiceDefinition) {
        let identifier = definition.globalIdentifier
        if expandedGroups.contains(identifier) {
            expandedGroups.remove(identifier)
        } else {
            expandedGroups.insert(identifier)
        }
        preferences.expandedServiceGroups = Array(expandedGroups)
    }

    // MARK: - Notification overrides

    func notificationOverride(for definition: ServiceDefinition) -> NotificationGranularity? {
        preferences.serviceNotificationOverrides[definition.globalIdentifier]
    }

    func setNotificationOverride(_ granularity: NotificationGranularity?, for definition: ServiceDefinition) {
        preferences.setNotificationGranularity(granularity, forIdentifier: definition.globalIdentifier)
        objectWillChange.send()
    }

    // MARK: - Custom services

    /// Saved, then enabled — adding one is asking to watch it.
    func addCustomService(_ service: CustomService) {
        customServiceStore.add(service)
        customServicesDidChange()
        enableCustomServices(ids: [service.id])
    }

    func updateCustomService(_ service: CustomService) {
        customServiceStore.update(service)
        customServicesDidChange()
        onCustomServiceChange?([service.globalIdentifier])
    }

    func deleteCustomService(_ service: CustomService) {
        // Disabled while its definition still resolves, so it leaves the popup cleanly.
        if let definition = serviceLoader.serviceDefinition(forIdentifier: service.globalIdentifier) {
            setEnabled(false, for: [definition])
        }
        preferences.setNotificationGranularity(nil, forIdentifier: service.globalIdentifier)
        customServiceStore.delete(id: service.id)
        customServicesDidChange()
    }

    func isCustomServiceEnabled(_ service: CustomService) -> Bool {
        enabledIdentifiers.contains(service.globalIdentifier)
    }

    func customServiceEnabledBinding(for service: CustomService) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isCustomServiceEnabled(service) ?? false },
            set: { [weak self] isEnabled in
                guard
                    let self,
                    let definition = serviceLoader.serviceDefinition(forIdentifier: service.globalIdentifier)
                else { return }
                setEnabled(isEnabled, for: [definition])
            }
        )
    }

    func customServiceNotificationBinding(for service: CustomService) -> Binding<NotificationGranularity?> {
        Binding(
            get: { [weak self] in self?.preferences.serviceNotificationOverrides[service.globalIdentifier] },
            set: { [weak self] granularity in
                self?.preferences.setNotificationGranularity(granularity, forIdentifier: service.globalIdentifier)
                self?.objectWillChange.send()
            }
        )
    }

    /// One real request for the editor's Test now; the draft doesn't need to be saved.
    func testCustomService(_ service: CustomService) async -> CustomService.CheckResult {
        await CustomServiceChecker.check(service)
    }

    func exportCustomServices() throws -> Data {
        try customServiceStore.exportData()
    }

    /// New services are enabled; replaced ones keep their state and are rebuilt in the popup.
    func importCustomServices(_ data: Data) throws -> CustomServiceStore.ImportSummary {
        let summary = try customServiceStore.importData(data)
        customServicesDidChange()
        enableCustomServices(ids: summary.addedIDs)
        let replaced = Set(summary.replacedIDs.map(CustomService.globalIdentifier(for:)))
        if !replaced.isEmpty {
            onCustomServiceChange?(replaced)
        }
        return summary
    }

    /// The loader serves custom services from the store, so it re-reads after every change.
    private func customServicesDidChange() {
        serviceLoader.reload()
        customServices = customServiceStore.services
    }

    private func enableCustomServices(ids: [UUID]) {
        let definitions = ids.compactMap {
            serviceLoader.serviceDefinition(forIdentifier: CustomService.globalIdentifier(for: $0))
        }
        guard !definitions.isEmpty else { return }
        setEnabled(true, for: definitions)
    }

    // MARK: - The catalogue

    /// The sub-services under a category.
    ///
    /// Providers with a data-driven `categoryKey` (Salesforce, Adobe, AWS) group by that value
    /// directly — a plain property filter, resolved and cached lazily here since there's nothing
    /// to gain from doing it any earlier. Everything else was populated in bulk by
    /// `precomputeReflectionBasedChildren()` when the model was last reloaded; see that method for
    /// why the two paths are split.
    func children(of categoryDefinition: ServiceDefinition) -> [ServiceDefinition] {
        let identifier = categoryDefinition.globalIdentifier
        if let cached = childrenCache[identifier] { return cached }

        guard let categoryKey = categoryDefinition.categoryKey else { return [] }

        let subServices = serviceLoader.allServices.filter { serviceDefinition in
            serviceDefinition.isSubService == true &&
            serviceDefinition.providerIdentifier == categoryDefinition.providerIdentifier &&
            serviceDefinition.categoryKey == categoryKey
        }.sorted(by: ServiceDefinitionSortByName)

        childrenCache[identifier] = subServices
        return subServices
    }

    /// Resolves every `subServiceSuperclass`-based category's children in one pass, instead of
    /// scanning per category. The fallback match needs to `build()` every sub-service definition to
    /// find its actual Swift type (`ServiceDefinition` alone doesn't carry it) — doing that once per
    /// category meant rebuilding the same sub-service repeatedly across ~20 categories. Building
    /// each sub-service exactly once and bucketing it by matched type makes it one build each.
    private func precomputeReflectionBasedChildren() {
        var categoriesBySuperclass: [ObjectIdentifier: ServiceDefinition] = [:]
        for categoryDefinition in topLevelServices
        where categoryDefinition.isCategory == true && categoryDefinition.categoryKey == nil {
            guard let serviceCategory = categoryDefinition.build() as? ServiceCategory else { continue }
            categoriesBySuperclass[ObjectIdentifier(serviceCategory.subServiceSuperclass)] = categoryDefinition
        }
        guard !categoriesBySuperclass.isEmpty else { return }

        var childrenByCategory: [String: [ServiceDefinition]] = [:]
        for definition in serviceLoader.allServices where definition.isSubService == true {
            guard let service = definition.build(), !(service is ServiceCategory) else { continue }

            let mirror = Mirror(reflecting: service)
            let candidateTypes = [mirror.subjectType, mirror.superclassMirror?.subjectType].compactMap { $0 }
            guard
                let category = candidateTypes.lazy.compactMap({ categoriesBySuperclass[ObjectIdentifier($0)] }).first
            else { continue }

            childrenByCategory[category.globalIdentifier, default: []].append(definition)
        }

        for (identifier, children) in childrenByCategory {
            childrenCache[identifier] = children.sorted(by: ServiceDefinitionSortByName)
        }
    }

    func enabledCount(in categoryDefinition: ServiceDefinition) -> Int {
        ([categoryDefinition] + children(of: categoryDefinition))
            .filter { enabledIdentifiers.contains($0.globalIdentifier) }
            .count
    }

    // MARK: - Search

    /// Search hits within the selected filter — the whole catalogue under `all`, sub-services
    /// included, otherwise just that scope's list — matched on name and host.
    var searchResults: [ServiceDefinition] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return [] }

        return services(for: servicesFilter)
            .filter { definition in
                definition.name.lowercased().contains(term)
                    || (definition.url.host?.lowercased().contains(term) ?? false)
            }
            .sorted(by: ServiceDefinitionSortByName)
    }

    var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The second line under a search hit: which vendor a sub-service belongs to, since
    /// "CloudFront" on its own doesn't say "AWS", and otherwise the host the status comes from —
    /// search matches on host too, so a hit that didn't match on name needs it shown to explain.
    func searchSubtitle(for definition: ServiceDefinition) -> String {
        vendorSubtitle(for: definition) ?? definition.url.host ?? ""
    }

    /// The vendor line alone, for a flat list that wasn't produced by a search: a sub-service
    /// still needs its parent named, but nothing was matched on the host so it isn't shown.
    func vendorSubtitle(for definition: ServiceDefinition) -> String? {
        guard definition.isSubService == true, let parent = parent(of: definition) else { return nil }
        return parent.name
    }

    private func parent(of subService: ServiceDefinition) -> ServiceDefinition? {
        serviceLoader.allServicesWithoutSubServices.first { candidate in
            candidate.isCategory == true && children(of: candidate).contains(where: subService.eq)
        }
    }

    // MARK: - About

    /// When the catalogue was last fetched, read from the cache file's own modification date —
    /// `RemoteServicesUpdater` only writes it after a fetch decodes cleanly, so the file's mtime
    /// *is* the last successful update. `nil` before the first one (and in Debug builds, which
    /// never read the cache).
    var definitionsUpdated: Date? {
        guard let url = try? RemoteServiceDefinitionProvider.cachedServicesJSONURL() else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}

/// Adapts `Pane` to the framework's generic sidebar, which knows nothing about this app's own
/// `title`/`glyph`/`tint` naming.
extension PreferencesModel.Pane: PreferencesSidebarItem {
    var sidebarTitle: String { title }
    var sidebarIcon: NSImage { glyph.image() }
    var sidebarTint: Color { tint }
}

/// The filter column's rows, for the same generic sidebar the pane list uses (in its tile-less
/// `.glyph` style). Glyphs are SF Symbols: the tile-centring problem that made the pane list draw
/// its own (`PreferencesGlyph`) doesn't arise for a bare icon beside text, which is what SF
/// Symbols are laid out for.
extension PreferencesModel.ServicesFilter: PreferencesSidebarItem {
    var sidebarTitle: String { title }

    var sidebarIcon: NSImage {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
            ?? NSImage(size: NSSize(width: 16, height: 16))
    }

    /// Monitoring in the app's green and Affected in the popup's incident amber; the rest in the
    /// secondary label colour, the way a source list's own glyphs sit.
    var sidebarTint: Color {
        switch self {
        case .monitoring: return PreferencesLayout.accent
        case .affected: return PopupLayout.Colors.dotMinor.swiftUI
        case .all, .notifying: return Color(nsColor: .secondaryLabelColor)
        }
    }
}
