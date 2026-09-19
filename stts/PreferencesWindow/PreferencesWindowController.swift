//
//  PreferencesWindowController.swift
//  stts
//

import Cocoa
import SwiftUI

/// Hosts the settings window.
///
/// Everything inside is SwiftUI (`PreferencesRootView`); AppKit's job here is the window itself —
/// creating it, sizing it, and bringing it to the front from a menu bar app that has no Dock icon.
/// A stock titled window, so the titlebar, traffic lights and toolbar are the system's.
class PreferencesWindowController: NSWindowController {
    private let model: PreferencesModel

    /// Persists the window's frame in user defaults so it reopens where it was last left.
    private static let frameAutosaveName = "PreferencesWindow"

    init(model: PreferencesModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PreferencesLayout.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "stts Settings"
        window.toolbarStyle = .unified
        window.minSize = PreferencesLayout.minWindowSize
        window.contentView = NSHostingView(rootView: PreferencesRootView(model: model))
        window.setFrameAutosaveName(Self.frameAutosaveName)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Selects a pane by index, as if its sidebar row had been clicked. Used by `SettingsSnapshot`,
    /// which walks every pane in turn.
    func selectPane(at index: Int) {
        let panes = PreferencesModel.Pane.allCases
        guard panes.indices.contains(index) else { return }
        model.selectedPane = panes[index]
    }

    func show() {
        model.reload()

        NSApplication.shared.activate(ignoringOtherApps: true)
        // Restore the last frame; only fall back to the default size and centering when there's
        // no saved one (first launch). Must happen before showWindow(): ordering the window on
        // screen autosaves its current frame, and restoring after that would just read it back.
        if window?.isVisible != true, window?.setFrameUsingName(Self.frameAutosaveName) != true {
            window?.setContentSize(PreferencesLayout.windowSize)
            window?.center()
        }
        showWindow(nil)

        // Deferred to the next run loop turn: ordering the window front in the same turn as activate()
        // can resolve before activation actually completes, leaving the window behind other apps.
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
            self?.window?.orderFrontRegardless()
        }
    }
}
