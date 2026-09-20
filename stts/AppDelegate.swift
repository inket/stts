//
//  AppDelegate.swift
//  stts
//

import Cocoa
import MBPopup
import Reachability
import UserNotifications

@NSApplicationMain @MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Off during unit testing, so the timer doesn't check services and cache statuses ahead of the tests.
    private var shouldAutomaticallyCheckServices: Bool {
        ProcessInfo.processInfo.environment["UNIT_TESTING"] == nil
    }

    private var timer: Timer?
    private var remoteServicesTimer: Timer?
    private let remoteServicesUpdater: RemoteServicesUpdater?

    private let reachability = try! Reachability() // swiftlint:disable:this force_try
    private var initialReachabilityChange: Bool = true

    let popupController: MBPopupController
    private let popupViewController: PopupViewController
    private let menuBarItemView = MenuBarItemView(frame: .zero)
    private let notificationDelegate: NotificationDelegate

    private let serviceLoader: ServiceLoader
    private let preferences: Preferences
    private let preferencesWindow: PreferencesWindow

    override init() {
        var serviceDefinitionProviders: [ServiceDefinitionProvider] = []

        // swiftlint:disable:next force_try
        let appDefinedProvider = try! AppDefinedServiceDefinitionProvider()
        #if DEBUG
        // Debug builds read only the bundled Resources/services.json — in release the remote copy
        // wholesale-replaces the bundled one (see below), which would make an unpushed local edit
        // invisible and could delete a local addition the remote copy doesn't have yet.
        serviceDefinitionProviders.append(appDefinedProvider)
        #else
        if let remoteProvider = try? RemoteServiceDefinitionProvider() {
            // Wholesale swap, not a per-identifier merge, so a service the remote copy drops doesn't
            // linger just because the bundled copy still has it. Falls back to the bundled copy
            // entirely until the remote one has fetched successfully at least once.
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
        notificationDelegate = NotificationDelegate(popupController: popupController)
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

        UNUserNotificationCenter.current().delegate = notificationDelegate
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
        // MBPopup insets the content by 1pt by default, leaving a frame of the panel fill (tinted
        // with the crown colour) showing around it. Content covers the panel edge to edge instead;
        // the border is drawn inside it (`PopupContentView`).
        popupController.contentInset = 0
        // Setting `contentInset` resizes the panel to the container view's *current* size, which is
        // still zero this early — before any layout pass has run. Put the intended size back.
        popupController.resizePopup(width: PopupLayout.contentWidth, height: PopupLayout.maxHeight)

        // MBPopup paints the arrow and the panel body with one colour; the body is covered by the
        // vibrancy view, so this value only actually shows through the arrow.
        // `refreshMenuBarItem()` keeps it in step with the current status.
        popupController.backgroundView.backgroundColor = .clear

        popupViewController.setup()

        preferencesWindow.selectionChangeCallback = { [weak self] in
            guard let self else { return }
            // Only the newly enabled services need a fetch; the rest keep their current status.
            let added = popupViewController.reloadServicesList()
            popupViewController.updateServices(only: added)
        }

        preferencesWindow.refreshIntervalCallback = { [weak self] _ in
            // The timer's interval is fixed at creation, so a new one takes a new timer. `fire()`
            // inside `restartTimer` also checks immediately, which is what you want after picking
            // a shorter interval.
            self?.restartTimer()
        }

        // The app's windows follow the General pane's Appearance setting, not the system's, unless
        // it says to match the system (in which case this is nil and AppKit does the usual thing).
        NSApp.appearance = preferences.appearancePreference.appearance

        popupController.willOpenPopup = { [weak self] _ in
            self?.popupViewController.willOpenPopup()
        }

        // MBPopup hides `contentView` before the fade-out animation begins, so the panel's own
        // background fill (tinted to the crown colour, normally just a sliver behind the arrow)
        // would fill the whole shape and fade out as a flash. Clear it first instead.
        popupController.willClosePopup = { [weak popupController] in
            popupController?.backgroundView.backgroundColor = .clear
            popupController?.backgroundView.needsDisplay = true
        }

        if shouldAutomaticallyCheckServices {
            Task { await startCheckingServices() }
        }

        #if DEBUG
        // Convenience for working on the settings window: skip the menu-bar-click round trip and
        // land straight in it. Never in a release build.
        preferencesWindow.show()
        #endif
    }

    private static let remoteServicesRefreshInterval: TimeInterval = 3 * 60 * 60
    /// How long the first check waits for the remote services.json before going ahead with the
    /// local copy.
    private static let remoteServicesLaunchTimeout: TimeInterval = 5

    /// Fetches the remote services.json *before* the first check so the services aren't checked
    /// once against the local copy and then again against the freshly fetched one. If the fetch
    /// takes longer than `remoteServicesLaunchTimeout`, the first check runs with the local copy
    /// and the fetch keeps going in the background, applying itself (with a re-check) on arrival.
    private func startCheckingServices() async {
        let fetch = Task { [remoteServicesUpdater] in await remoteServicesUpdater?.update() ?? false }

        switch await Self.withTimeout(Self.remoteServicesLaunchTimeout, { await fetch.value }) {
        case .some(true):
            applyReloadedServiceDefinitions()
        case .some(false):
            break
        case .none:
            Task { [weak self] in
                guard await fetch.value, let self else { return }
                applyReloadedServiceDefinitions()
                updateServices()
            }
        }

        restartTimer()
        startRemoteServicesTimer()
    }

    /// Runs `operation`, giving up (but not cancelling it) after `seconds`. `nil` means it timed out.
    private static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @Sendable () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func startRemoteServicesTimer() {
        remoteServicesTimer?.invalidate()
        remoteServicesTimer = Timer.scheduledTimer(
            withTimeInterval: Self.remoteServicesRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.refreshRemoteServices() }
        }
    }

    private func refreshRemoteServices() async {
        guard let remoteServicesUpdater, await remoteServicesUpdater.update() else { return }

        applyReloadedServiceDefinitions()
        // The rebuilt services start at .undetermined/"Loading", so fetch them right away rather
        // than leaving them stuck until the next scheduled update.
        updateServices()
    }

    /// Re-reads the (possibly just re-fetched) definitions and, since they may have changed,
    /// rebuilds every BaseService from scratch.
    private func applyReloadedServiceDefinitions() {
        serviceLoader.reload()
        SendbirdAll.sendbirdServices = serviceLoader.allServices
            .compactMap { $0 as? SendbirdServiceDefinition }
            .compactMap { $0.build() as? SendbirdService }
        popupViewController.rebuildServicesList()
    }

    @objc
    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(preferences.refreshInterval),
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
        preferencesWindow.updateStatuses(popupViewController.identifiedServices)

        popupController.backgroundView.backgroundColor = popupViewController.crownColor
        popupController.backgroundView.needsDisplay = true
    }

    @objc func updateServices() {
        popupViewController.updateServices { [weak self] in
            guard let self else { return }

            // No global on/off check here: `.never` is a granularity like any other, and a
            // service with an override is meant to notify even when the app-wide setting says
            // nothing should.
            popupViewController.identifiedServices.forEach { identifier, service in
                service.notifyIfStatusChanged(
                    granularity: self.preferences.notificationGranularity(forIdentifier: identifier)
                )
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if preferencesWindow.isVisible {
            preferencesWindow.show()
        } else {
            popupController.openPopup()
        }
        return true
    }

    private func reachabilityChanged() {
        if initialReachabilityChange {
            // Reachability fires once on launch after startNotifier() — skip it to avoid a duplicate updateServices().
            initialReachabilityChange = false
        } else {
            updateServices()
        }
    }
}

extension AppDelegate: AppearanceObserver {
    func changeAppearance(to newAppearance: NSAppearance) {
        // `backgroundColor` is a dynamic colour and resolves itself when MBPopup fills with it, so
        // switching appearance only needs to force a redraw.
        popupController.backgroundView.needsDisplay = true
    }
}
