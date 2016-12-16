//
//  Preferences.swift
//  stts
//

import Cocoa

struct Preferences {
    static var shared = Preferences()

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
            "selectedServices" : ["CircleCI", "CloudFlare", "GitHub", "NPM", "TravisCI"]
        ])
    }
}
