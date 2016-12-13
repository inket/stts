//
//  Preferences.swift
//  stts
//

import Cocoa

struct Preferences {
    static var shared = Preferences()

    var selectedServices: [Service] {
        get {
            let serviceNames = UserDefaults.standard.array(forKey: "selectedServices") as? [String]
            guard let classNames = serviceNames, classNames.count > 0 else { return [] }

            return classNames.map {
                ((NSClassFromString($0) ?? NSClassFromString("stts.\($0)")) as? Service.Type)?.init()
            }.flatMap { $0 }.sorted()
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
