//
//  Preferences.swift
//  stts
//

import Foundation

struct Preferences {
    static var shared = Preferences()

    var notifyOnStatusChange: Bool {
        get { UserDefaults.standard.bool(forKey: "notifyOnStatusChange") }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnStatusChange") }
    }

    var selectedServices: [ServiceDefinition] {
        get {
            let identifiers = UserDefaults.standard.array(forKey: "selectedServices") as? [String] ?? []

            // Match the identifiers to our loaded service definitions
            let definitions = identifiers.map(ServiceLoader.current.serviceDefinition(forIdentifier:)).compactMap { $0 }
            let sortedDefinitions = definitions.sorted { a, b in
                a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            return sortedDefinitions
        }

        set {
            let identifiers = newValue.map { $0.globalIdentifier }
            UserDefaults.standard.set(identifiers, forKey: "selectedServices")
        }
    }

    init() {
        UserDefaults.standard.register(defaults: [
            "notifyOnStatusChange": true,
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
            // Generated services
            "FirebaseMLKit": "FirebaseMachineLearning"
        ]

        if var services = UserDefaults.standard.array(forKey: "selectedServices") as? [String] {
            for (index, oldClassName) in services.enumerated() {
                if let newClassName = migrationMapping[oldClassName] {
                    services[index] = newClassName

                    debugPrint("Replaced service \(oldClassName) with \(newClassName)")
                }
            }

            UserDefaults.standard.setValue(services, forKey: "selectedServices")
        }
    }
}
