//
//  Preferences.swift
//  stts
//

import Foundation

@MainActor
class Preferences {
    private let serviceLoader: ServiceLoader

    var notifyOnStatusChange: Bool {
        get { UserDefaults.standard.bool(forKey: "notifyOnStatusChange") }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnStatusChange") }
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
            "notifyOnStatusChange": true,
            "selectedServices": ["CircleCI", "Cloudflare", "GitHub", "NPM", "TravisCI"]
        ])

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
