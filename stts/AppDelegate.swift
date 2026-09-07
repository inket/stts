//
//  AppDelegate.swift
//  stts
//

import Cocoa
import MBPopup
import PreferencesWindow
import Reachability
import UserNotifications

@NSApplicationMain
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var shouldAutomaticallyCheckServices: Bool {
        // We don't want to start the updating timer when unit testing because:
        // 1. It will be checking services unnecessarily
        // 2. It will check services that have a Store (like Adobe) before our tests and cache statuses
        return ProcessInfo.processInfo.environment["UNIT_TESTING"] == nil
    }

    private var timer: Timer?
    private var remoteServicesTimer: Timer?
    private let remoteServicesUpdater: RemoteServicesUpdater?

    private let reachability = try! Reachability() // swiftlint:disable:this force_try
    private var initialReachabilityChange: Bool = true

    let popupController: MBPopupController
    private let popupViewController: PopupViewController
    private let menuBarItemView = MenuBarItemView(frame: .zero)

    private let serviceLoader: ServiceLoader
    private let preferences: Preferences
    private let preferencesWindow: PreferencesWindow

    override init() {
        var serviceDefinitionProviders: [ServiceDefinitionProvider] = []

        // swiftlint:disable:next force_try
        let appDefinedProvider = try! AppDefinedServiceDefinitionProvider()
        #if DEBUG
        // Debug builds read only the bundled Resources/services.json, so what a developer is
        // actually editing is what the app shows. In release the remote copy wholesale-replaces the
        // bundled one (see below), which means an unpushed local edit is invisible — worse, a local
        // addition that master doesn't have yet is actively deleted by the copy fetched from master.
        // That's correct for shipped builds and useless while working on the file.
        serviceDefinitionProviders.append(appDefinedProvider)
        #else
        if let remoteProvider = try? RemoteServiceDefinitionProvider() {
            // Wholesale swap, not a per-identifier merge: once the remote copy has any data, it
            // fully replaces the bundled one rather than being unioned with it, so a service the
            // remote copy drops doesn't linger just because the (older) bundled copy still has it.
            // Falls back to the bundled copy entirely when remote hasn't fetched anything successfully
            // yet.
            serviceDefinitionProviders.append(
                FallbackServiceDefinitionProvider(primary: remoteProvider, fallback: appDefinedProvider)
            )
        } else {
            serviceDefinitionProviders.append(appDefinedProvider)
        }
        #endif
        if let userDefinedProvider = try? UserDefinedServiceDefinitionProvider() {
            serviceDefinitionProviders.append(userDefinedProvider)
        }
        serviceLoader = ServiceLoader(providers: serviceDefinitionProviders)
        SendbirdAll.sendbirdServices = serviceLoader.allServices
            .compactMap { $0 as? SendbirdServiceDefinition }
            .compactMap { $0.build() as? SendbirdService }

        remoteServicesUpdater = (try? RemoteServiceDefinitionProvider.cachedServicesJSONURL())
            .map { RemoteServicesUpdater(destinationURL: $0) }

        preferences = Preferences(serviceLoader: serviceLoader)
        preferencesWindow = PreferencesWindow(serviceLoader: serviceLoader, preferences: preferences)

        popupViewController = PopupViewController(
            serviceLoader: serviceLoader,
            preferences: preferences,
            preferencesWindow: preferencesWindow
        )

        popupController = MBPopupController(contentView: popupViewController.contentView)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if DEBUG
        if PopupSnapshot.isRequested {
            PopupSnapshot.emit()
            NSApp.terminate(nil)
            return
        }
        #endif

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(AppDelegate.restartTimer),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        if shouldAutomaticallyCheckServices {
            reachability.whenReachable = { [weak self] _ in self?.reachabilityChanged() }
            reachability.whenUnreachable = { [weak self] _ in self?.reachabilityChanged() }
        }

        try? reachability.startNotifier()

        Appearance.addObserver(self)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        popupController.statusItem.length = 30
        setupMenuBarItemView()

        popupController.contentView.wantsLayer = true
        popupController.contentView.layer?.masksToBounds = true
        // `masksToBounds` alone only clips to a rectangle — without also rounding this layer's own
        // corners, the content's square corners poke past the panel's rounded shape. It also clips
        // the vibrancy view to the same rounded rect.
        popupController.contentView.layer?.cornerRadius = PopupLayout.cornerRadius

        popupController.backgroundView.cornerRadius = PopupLayout.cornerRadius
        popupController.arrowSize = PopupLayout.arrowSize
        // MBPopup paints the arrow and the panel body with one colour. The body is covered by the
        // vibrancy view and its tint, so what this value actually shows is the arrow — which the
        // design tints with the crown's colour, so the band appears to continue up into the menu
        // bar. `refreshMenuBarItem()` keeps it in step with the current status.
        popupController.backgroundView.backgroundColor = .clear

        popupViewController.setup()

        preferencesWindow.saveCallback = { [weak self] in
            self?.popupViewController.reloadServicesList()
            self?.updateServices()
        }

        popupController.willOpenPopup = { [weak self] _ in
            self?.popupViewController.willOpenPopup()
        }

        if shouldAutomaticallyCheckServices {
            restartTimer()
            restartRemoteServicesTimer()
        }
    }

    private static let remoteServicesRefreshInterval: TimeInterval = 3 * 60 * 60

    private func restartRemoteServicesTimer() {
        remoteServicesTimer?.invalidate()
        remoteServicesTimer = Timer.scheduledTimer(
            withTimeInterval: Self.remoteServicesRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.refreshRemoteServices() }
        }
        remoteServicesTimer?.fire()
    }

    private func refreshRemoteServices() async {
        guard let remoteServicesUpdater, await remoteServicesUpdater.update() else { return }

        serviceLoader.reload()
        SendbirdAll.sendbirdServices = serviceLoader.allServices
            .compactMap { $0 as? SendbirdServiceDefinition }
            .compactMap { $0.build() as? SendbirdService }

        // reloadServicesList() rebuilds `services` with fresh BaseService instances (always starting
        // at .undetermined/"Loading"), which orphans whatever the in-flight updateServices() fetch
        // (e.g. from app launch) was updating and leaves the new instances stuck showing "Loading"
        // until the next scheduled update. Re-running updateServices() here fetches them right away.
        popupViewController.reloadServicesList()
        updateServices()
    }

    @objc
    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 300,
            target: self,
            selector: #selector(AppDelegate.updateServices),
            userInfo: nil,
            repeats: true
        )
        timer?.fire()
    }

    private func setupMenuBarItemView() {
        guard let button = popupController.statusItem.button else { return }

        button.title = ""
        menuBarItemView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(menuBarItemView)

        NSLayoutConstraint.activate([
            menuBarItemView.topAnchor.constraint(equalTo: button.topAnchor),
            menuBarItemView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            menuBarItemView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            menuBarItemView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        popupViewController.onStateChange = { [weak self] in self?.refreshMenuBarItem() }
        refreshMenuBarItem()
    }

    private func refreshMenuBarItem() {
        menuBarItemView.status = popupViewController.aggregateStatus
        menuBarItemView.isChecking = popupViewController.isChecking

        popupController.backgroundView.backgroundColor = popupViewController.crownColor
        popupController.backgroundView.needsDisplay = true
    }

    @objc func updateServices() {
        popupViewController.updateServices { [weak self] in
            guard let self else { return }

            if preferences.notifyOnStatusChange {
                popupViewController.services.forEach { $0.notifyIfStatusChanged() }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        popupController.openPopup()
        return true
    }

    private func reachabilityChanged() {
        if initialReachabilityChange {
            // Reachability notifies us of a change on app launch (after calling startNotifier()),
            // we don't need it because it causes duplicate updateServices()
            initialReachabilityChange = false
        } else {
            updateServices()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        popupController.openPopup()
        completionHandler()
    }
}

extension AppDelegate: AppearanceObserver {
    func changeAppearance(to newAppearance: NSAppearance) {
        // `backgroundColor` is a dynamic colour and resolves itself when MBPopup fills with it, so
        // switching appearance only needs to force a redraw.
        popupController.backgroundView.needsDisplay = true
    }
}
