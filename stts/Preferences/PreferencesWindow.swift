//
//  PreferencesWindow.swift
//  stts
//

import Cocoa

/// Owns the settings window's model and controller, and the two callbacks the rest of the app
/// needs to hear about.
///
/// The design has a fourth pane, Custom services, which isn't built yet — see
/// `Scripts/settings_redesign_plan.md`.
@MainActor
final class PreferencesWindow {
    let controller: PreferencesWindowController
    private let model: PreferencesModel

    /// Rebuilds the popup's services after the enabled set changes.
    var saveCallback: (() -> Void)? {
        get { model.onSelectionChange }
        set { model.onSelectionChange = newValue }
    }

    /// Applying a new check interval means restarting `AppDelegate`'s timer.
    var refreshIntervalCallback: ((Int) -> Void)? {
        get { model.onRefreshIntervalChange }
        set { model.onRefreshIntervalChange = newValue }
    }

    var isVisible: Bool {
        controller.window?.isVisible == true
    }

    /// Hands the Services pane the popup's latest statuses, which its "Affected" filter is built
    /// from. Cheap when nothing changed, so it's fine to call on every popup state change.
    func updateStatuses(_ services: [(identifier: String, service: BaseService)]) {
        model.updateStatuses(services)
    }

    init(serviceLoader: ServiceLoader, preferences: Preferences) {
        model = PreferencesModel(serviceLoader: serviceLoader, preferences: preferences)
        controller = PreferencesWindowController(model: model)
    }

    func show() {
        controller.show()
    }
}
