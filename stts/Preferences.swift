//
//  Preferences.swift
//  stts
//

import Cocoa

/// How much a status change has to matter before it's worth a notification.
///
/// Replaces the old `notifyOnStatusChange` boolean, which could only say "all" or "none". The
/// middle case is the one people actually wanted: tell me when something breaks, not when a
/// provider posts a scheduled-maintenance notice.
enum NotificationGranularity: String, CaseIterable {
    case everyChange
    case outagesOnly
    case never

    var title: String {
        switch self {
        case .everyChange: return "Every change"
        case .outagesOnly: return "Outages only"
        case .never: return "Never"
        }
    }

    /// Whether a transition is worth announcing.
    ///
    /// `outagesOnly` keeps *both* sides of an outage — going down and coming back — because a
    /// notification that something broke is only half the story, and the recovery is the half
    /// people are waiting for. What it drops is everything that never involved an outage at all:
    /// maintenance windows, notices, and the flip between them.
    func shouldNotify(from oldStatus: ServiceStatus, to newStatus: ServiceStatus) -> Bool {
        switch self {
        case .everyChange: return true
        case .outagesOnly: return oldStatus.isOutage || newStatus.isOutage
        case .never: return false
        }
    }
}

/// Which appearance the app's own windows use, independent of the system's.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: return "Match system"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` means "don't override" — `NSApp.appearance = nil` is how AppKit spells "follow the
    /// system", so this maps straight onto it.
    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
class Preferences {
    /// The intervals the General pane offers, in seconds.
    static let refreshIntervalOptions: [Int] = [60, 300, 900, 1800]

    private let serviceLoader: ServiceLoader

    /// How often every enabled service is re-checked, in seconds. Was hardcoded at 300 in
    /// `AppDelegate.restartTimer` before the settings redesign.
    var refreshInterval: Int {
        get { UserDefaults.standard.integer(forKey: "refreshInterval") }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval") }
    }

    /// The app-wide default. Individual services can override it — see
    /// `notificationGranularity(forIdentifier:)`.
    var notificationGranularity: NotificationGranularity {
        get {
            UserDefaults.standard.string(forKey: "notificationGranularity")
                .flatMap(NotificationGranularity.init(rawValue:)) ?? .everyChange
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "notificationGranularity") }
    }

    var appearancePreference: AppearancePreference {
        get {
            UserDefaults.standard.string(forKey: "appearancePreference")
                .flatMap(AppearancePreference.init(rawValue:)) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appearancePreference") }
    }

    /// Per-service overrides of `notificationGranularity`, keyed by global identifier. An absent
    /// key inherits; there's deliberately no "inherit" case stored, so changing the General setting
    /// keeps moving every service that never opted out.
    var serviceNotificationOverrides: [String: NotificationGranularity] {
        get {
            let stored = UserDefaults.standard.dictionary(forKey: "serviceNotificationOverrides") as? [String: String]
            return (stored ?? [:]).compactMapValues(NotificationGranularity.init(rawValue:))
        }
        set {
            UserDefaults.standard.set(newValue.mapValues { $0.rawValue }, forKey: "serviceNotificationOverrides")
        }
    }

    /// Which service groups are left open in the Services list, as global identifiers of the
    /// category definitions.
    var expandedServiceGroups: [String] {
        get { UserDefaults.standard.array(forKey: "expandedServiceGroups") as? [String] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "expandedServiceGroups") }
    }

    func notificationGranularity(forIdentifier identifier: String) -> NotificationGranularity {
        serviceNotificationOverrides[identifier] ?? notificationGranularity
    }

    func setNotificationGranularity(_ granularity: NotificationGranularity?, forIdentifier identifier: String) {
        var overrides = serviceNotificationOverrides
        overrides[identifier] = granularity
        serviceNotificationOverrides = overrides
    }

    var selectedServices: [ServiceDefinition] {
        get {
            let identifiers = UserDefaults.standard.array(forKey: "selectedServices") as? [String] ?? []

            // Match the identifiers to our loaded service definitions
            let definitions = identifiers.map(serviceLoader.serviceDefinition(forIdentifier:)).compactMap { $0 }
            let sortedDefinitions = definitions.sorted(by: ServiceDefinitionSortByName)

            return sortedDefinitions
        }

        set {
            let identifiers = newValue.map { $0.globalIdentifier }
            UserDefaults.standard.set(identifiers, forKey: "selectedServices")
        }
    }

    init(serviceLoader: ServiceLoader) {
        self.serviceLoader = serviceLoader

        UserDefaults.standard.register(defaults: [
            "notificationGranularity": NotificationGranularity.everyChange.rawValue,
            "appearancePreference": AppearancePreference.system.rawValue,
            "refreshInterval": 300,
            "selectedServices": ["CircleCI", "Cloudflare", "GitHub", "NPM", "TravisCI"]
        ])

        Preferences.migrateNotificationPreference()
        Preferences.migrate()
        removeDeletedServices()
    }

    /// Prunes stored identifiers for services services.json's `_removed` key declares gone for good
    /// (not just currently broken/unreachable — see `ServicesStructure.removedServices`), instead of
    /// leaving them silently unmatched forever. Only prunes an identifier if it doesn't *also* still
    /// resolve to a real service, as a safety net against a mistaken/overly broad `_removed` entry.
    private func removeDeletedServices() {
        let removedIdentifiers = serviceLoader.removedIdentifiers
        guard !removedIdentifiers.isEmpty else { return }

        guard let services = UserDefaults.standard.array(forKey: "selectedServices") as? [String] else { return }

        let remainingServices = services.filter { identifier in
            guard removedIdentifiers.contains(identifier) else { return true }

            let stillResolves = serviceLoader.serviceDefinition(forIdentifier: identifier) != nil
            if !stillResolves {
                debugPrint("Removed deleted service \(identifier)")
            }
            return stillResolves
        }

        if remainingServices != services {
            UserDefaults.standard.setValue(remainingServices, forKey: "selectedServices")
        }
    }

    /// Carries the old `notifyOnStatusChange` boolean over to `notificationGranularity`:
    /// `false → never`, `true → everyChange`. Runs once — the old key is removed afterwards, so a
    /// later change to the new setting can't be undone by this on the next launch.
    private static func migrateNotificationPreference() {
        guard UserDefaults.standard.object(forKey: "notifyOnStatusChange") != nil else { return }

        let granularity: NotificationGranularity =
            UserDefaults.standard.bool(forKey: "notifyOnStatusChange") ? .everyChange : .never
        UserDefaults.standard.set(granularity.rawValue, forKey: "notificationGranularity")
        UserDefaults.standard.removeObject(forKey: "notifyOnStatusChange")
    }

    private static func migrate() {
        // Migrate old names to new names if needed
        let migrationMapping: [String: String] = [
            "CloudFlare": "Cloudflare", // v1.0.0 used the name "CloudFlare" instead of the official "Cloudflare"
            "Apple": "AppleAll", // Apple changed from one service to multiple sub services
            "AppleDeveloper": "AppleDeveloperAll", // Apple Developer changed from one service to multiple sub services
            "VMwareCarbonBlack": "Broadcom", // v2.23
            "Spoke": "Okta", // v2.23
            // There were many others but they were migrated to the services.json file
            // Generated services
            "FirebaseMLKit": "FirebaseMachineLearning",
            "AdobeAdobePhotoshopAPI": "AdobePhotoshopAPI",

            // 2026-08: these services' status pages moved to a different underlying provider,
            // which changes their globalIdentifier's provider prefix even though it's the same service.
            "statuspage.Fivetran": "independent.Fivetran",
            "statuspage.Notion": "incidentio.Notion",
            "independent.Recurly": "incidentio.Recurly",
            "statusiov1.SumoLogic": "statuspage.SumoLogic",
            "independent.PagerDuty": "pagerduty.PagerDuty",
            "independent.SignalWire": "pagerduty.SignalWire",
            "statuspage.Platformsh": "independent.Upsun", // Also rebranded from "Platform.sh" to "Upsun"
            "instatus.Railway": "independent.Railway"
        ]

        if var services = UserDefaults.standard.array(forKey: "selectedServices") as? [String] {
            for (index, oldClassName) in services.enumerated() {
                if let newClassName = migrationMapping[oldClassName] {
                    services[index] = newClassName

                    debugPrint("Replaced service \(oldClassName) with \(newClassName)")
                }
            }

            let uniqueServices = Set<String>(services)

            UserDefaults.standard.setValue(Array(uniqueServices), forKey: "selectedServices")
        }
    }
}
