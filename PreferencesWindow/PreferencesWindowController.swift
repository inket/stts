//
//  PreferencesWindowController.swift
//  PreferencesWindow
//

import Cocoa

public class PreferencesWindowController: NSWindowController {
    public let menuItems: [PreferencesSidebarMenuItem]

    private lazy var sidebarViewController = PreferencesSidebarViewController(menuItems: menuItems)
    private lazy var preferencesContentViewController = PreferencesContentViewController()

    public init(menuItems: [PreferencesSidebarMenuItem]) {
        self.menuItems = menuItems

        let window = NSWindow()
        window.styleMask = [.titled, .fullSizeContentView, .closable, .miniaturizable, .resizable]
        window.hasShadow = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        super.init(window: window)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sidebarViewController.onSelectionChange = { [weak self] selectedMenuItem in
            self?.preferencesContentViewController.currentView = selectedMenuItem.view
        }

        let splitViewController = NSSplitViewController()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.canCollapse = false

        let contentItem = NSSplitViewItem(viewController: preferencesContentViewController)
        contentItem.canCollapse = false

        splitViewController.splitViewItems = [sidebarItem, contentItem]
        contentViewController = splitViewController
    }

    public func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
    }
}
