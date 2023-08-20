//
//  PreferencesWindow.swift
//  stts
//

import Cocoa
import PreferencesWindow
import SFSafeSymbols

class PreferencesGeneralView: NSView, PreferencesView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.red.cgColor

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 400),
            widthAnchor.constraint(equalToConstant: 400),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func willShow() {}
}

class PreferencesAboutView: NSView, PreferencesView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.green.cgColor

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 400),
            widthAnchor.constraint(equalToConstant: 400),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func willShow() {}
}

class PreferencesWindow {
    let controller: PreferencesWindowController

    init(serviceLoader: ServiceLoader, preferences: Preferences) {
         controller = PreferencesWindowController(menuItems: [
            Self.generalMenuItem(),
            Self.servicesMenuItem(serviceLoader: serviceLoader, preferences: preferences),
            Self.aboutMenuItem()
         ])
    }

    func show() {
        controller.show()
    }

    private static func generalMenuItem() -> PreferencesSidebarMenuItem {
        PreferencesSidebarMenuItem(
            title: "General",
            symbol: .gearshapeFill,
            view: PreferencesGeneralView()
        )
    }

    private static func servicesMenuItem(
        serviceLoader: ServiceLoader,
        preferences: Preferences
    ) -> PreferencesSidebarMenuItem {
        PreferencesSidebarMenuItem(
            title: "Services",
            symbol: .boltCircleFill,
            view: PreferencesServicesView(serviceLoader: serviceLoader, preferences: preferences)
        )
    }

    private static func aboutMenuItem() -> PreferencesSidebarMenuItem {
        PreferencesSidebarMenuItem(
            title: "About",
            symbol: .infoCircleFill,
            view: PreferencesAboutView()
        )
    }
}
