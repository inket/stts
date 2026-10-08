//
//  PreferencesWindow.swift
//  stts
//

import Cocoa

/// Owns the settings window's model and controller, and the two callbacks the rest of the app
/// needs to hear about.
@MainActor
final class PreferencesWindow {
    let controller: PreferencesWindowController
    private let model: PreferencesModel

    /// Fired after the Services pane enables or disables something, so the popup can follow.
    var selectionChangeCallback: (() -> Void)? {
        get { model.onSelectionChange }
        set { model.onSelectionChange = newValue }
    }

    /// Fired after custom services are edited or imported, with the identifiers of the ones whose
    /// definition changed, so the popup can rebuild just those.
    var customServiceChangeCallback: ((Set<String>) -> Void)? {
        get { model.onCustomServiceChange }
        set { model.onCustomServiceChange = newValue }
    }

    /// Applying a new check interval means restarting `AppDelegate`'s timer.
    var refreshIntervalCallback: ((Int) -> Void)? {
        get { model.onRefreshIntervalChange }
        set { model.onRefreshIntervalChange = newValue }
    }

    var isVisible: Bool {
        controller.window?.isVisible == true
    }

    /// Hands the settings window the popup's latest statuses: the Services pane's "Affected"
    /// filter is built from them, and the Custom services pane's last results. Cheap when nothing
    /// changed, so it's fine to call on every popup state change.
    func updateStatuses(_ services: [(identifier: String, service: BaseService)]) {
        model.updateStatuses(services)
    }

    init(serviceLoader: ServiceLoader, preferences: Preferences, customServiceStore: CustomServiceStore) {
        model = PreferencesModel(
            serviceLoader: serviceLoader,
            preferences: preferences,
            customServiceStore: customServiceStore
        )
        controller = PreferencesWindowController(model: model)
    }

    func show() {
        controller.show()
    }

    func showServices() {
        model.selectedPane = .services
        model.servicesFilter = .all
        model.searchTerm = ""
        controller.show()
    }
}
