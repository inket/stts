//
//  Preferences.swift
//  stts
//

import Cocoa

struct Preferences {
    static var shared = Preferences()

    var notifyOnStatusChange: Bool {
        get { return UserDefaults.standard.bool(forKey: "notifyOnStatusChange") }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnStatusChange") }
    }

    var selectedServices: [Service] {
        get {
            guard let classNames = UserDefaults.standard.array(forKey: "selectedServices") as? [String] else {
                return []
            }

            return classNames.map(Service.named).flatMap { $0 }.sorted()
        }

        set {
            let classNames = newValue.map { "\(type(of: $0))" }
            UserDefaults.standard.set(classNames, forKey: "selectedServices")
        }
    }

    init() {
        UserDefaults.standard.register(defaults: [
            "notifyOnStatusChange": true,
            "selectedServices": ["CircleCI", "Cloudflare", "GitHub", "NPM", "TravisCI"]
        ])

        // A "migration" of sorts
        if var services = UserDefaults.standard.array(forKey: "selectedServices") as? [String] {
            // v1.0.0 used the name "CloudFlare" instead of the official "Cloudflare", replace it if found
            if let oldCloudflareIndex = services.index(of: "CloudFlare") {
                services[oldCloudflareIndex] = "Cloudflare"
            }

            UserDefaults.standard.setValue(services, forKey: "selectedServices")
        }
    }
}
