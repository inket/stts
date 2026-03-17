//
//  Preferences.swift
//  stts
//

import Foundation

class Preferences {
    private let serviceLoader: ServiceLoader

    var notifyOnStatusChange: Bool {
        get { UserDefaults.standard.bool(forKey: "notifyOnStatusChange") }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnStatusChange") }
    }

    var hideServiceDetailsIfAvailable: Bool {
        get { UserDefaults.standard.bool(forKey: "hideServiceDetailsIfAvailable") }
        set { UserDefaults.standard.set(newValue, forKey: "hideServiceDetailsIfAvailable") }
    }

    var allowPopupToStretchAsNeeded: Bool {
        get { UserDefaults.standard.bool(forKey: "allowPopupToStretchAsNeeded") }
        set { UserDefaults.standard.set(newValue, forKey: "allowPopupToStretchAsNeeded") }
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
            "hideServiceDetailsIfAvailable": false,
            "allowPopupToStretchAsNeeded": false,
            "selectedServices": ["CircleCI", "Cloudflare", "GitHub", "NPM", "TravisCI"]
        ])

        Preferences.migrate()
    }

    private static func migrate() {
        // Migrate old names to new names if needed
        let migrationMapping: [String: String] = [
            "CloudFlare": "Cloudflare", // v1.0.0 used the name "CloudFlare" instead of the official "Cloudflare"
            "Apple": "AppleAll", // Apple changed from one service to multiple sub services
            "AppleDeveloper": "AppleDeveloperAll", // Apple Developer changed from one service to multiple sub services
            "VMwareCarbonBlack": "Broadcom", // v2.23
            "Tableau": "TableauAll", // v2.23
            "Spoke": "Okta", // v2.23
            // There were many others but they were migrated to the services.json file
            // Generated services
            "FirebaseMLKit": "FirebaseMachineLearning",
            "AdobeAdobePhotoshopAPI": "AdobePhotoshopAPI"
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
