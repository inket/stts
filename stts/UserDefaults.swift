//
//  UserDefaults.swift
//  stts
//

import Cocoa

extension UserDefaults {
    static var notifyOnStatusChange: Bool {
        get { return UserDefaults.standard.bool(forKey: "notifyOnStatusChange") }
        set { UserDefaults.standard.set(newValue, forKey: "notifyOnStatusChange") }
    }

    open override class func initialize() {
        super.initialize()

        UserDefaults.standard.register(defaults: ["notifyOnStatusChange": true])
    }
}
