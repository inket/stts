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

    var hideServiceDetailsIfAvailable: Bool {
        get { UserDefaults.standard.bool(forKey: "hideServiceDetailsIfAvailable") }
        set { UserDefaults.standard.set(newValue, forKey: "hideServiceDetailsIfAvailable") }
    }

    var allowPopupToStretchAsNeeded: Bool {
        get { UserDefaults.standard.bool(forKey: "allowPopupToStretchAsNeeded") }
        set { UserDefaults.standard.set(newValue, forKey: "allowPopupToStretchAsNeeded") }
    }

    var selectedServices: [BaseService] {
        get {
            guard let classNames = UserDefaults.standard.array(forKey: "selectedServices") as? [String] else {
                return []
            }

            return classNames.map(BaseService.named).compactMap { $0 }.sorted()
        }

        set {
            let classNames = newValue.map { "\(type(of: $0))" }
            UserDefaults.standard.set(classNames, forKey: "selectedServices")
        }
    }

    private init() {
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
            "BitBucket": "Bitbucket", // v2.8
            "StatusPage": "Statuspage", // v2.8
            "ProtonMail": "Proton", // v2.12
            "Packet": "EquinixMetal", // v2.12
            "Quandl": "NasdaqDataLink", // v2.12
            "Quay": "QuayIO", // v2.12
            "SmartyStreets": "Smarty", // v2.12
            "UrbanAirship": "AirshipUS", // v2.19
            "VMwareCarbonBlack": "Broadcom", // v2.23
            "Tableau": "TableauAll", // v2.23
            "Spoke": "Okta", // v2.23
            "Intercom": "IntercomUS", // v2.24
            "Lumanox": "FilesCom", // v2.25
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

            let uniqueServices = Set<String>(services)

            UserDefaults.standard.setValue(Array(uniqueServices), forKey: "selectedServices")
        }
    }
}
