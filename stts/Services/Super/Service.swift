//
//  Service.swift
//  stts
//

import Foundation

enum ServiceStatus {
    case undetermined
    case good
    case maintenance
    case minor
    case major
}

class Service {
    var name: String { return "\(type(of: self))" }
    var status: ServiceStatus = .undetermined {
        didSet {
            if oldValue == .undetermined || status == .undetermined || oldValue == status {
                self.shouldNotify = false
            } else if Preferences.shared.notifyOnStatusChange {
                self.shouldNotify = true
            }
        }
    }
    var message: String = "Loading…"
    var url: URL { return URL(string: "")! }
    var shouldNotify = false

    static func all() -> [Service] {
        guard let servicesPlist = Bundle.main.path(forResource: "services", ofType: "plist"),
            let services = NSDictionary(contentsOfFile: servicesPlist)?["services"] as? [String] else {
                fatalError("The services.plist file does not exist. The build phase script might have failed.")
        }

        return services.map(Service.named).flatMap { $0 }
    }

    static func named(_ name: String) -> Service? {
        return (NSClassFromString("stts.\(name)") as? Service.Type)?.init()
    }

    required init() {}

    func updateStatus(callback: @escaping (Service) -> Void) {}

    func _fail(_ error: Error?) {
        self.status = .undetermined
        self.message = error?.localizedDescription ?? "Unexpected error"
    }

    func _fail(_ message: String) {
        self.status = .undetermined
        self.message = message
    }

    func notifyIfNecessary() {
        guard shouldNotify else { return }

        self.shouldNotify = false

        let notification = NSUserNotification()
        let possessiveS = name.hasSuffix("s") ? "'" : "'s"
        notification.title = "\(name)\(possessiveS) status has changed"
        notification.informativeText = message

        NSUserNotificationCenter.default.deliver(notification)
    }
}

extension Service: Equatable {
    public static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Service: Comparable {
    static func < (lhs: Service, rhs: Service) -> Bool {
        let sameStatus = lhs.status == rhs.status
        let differentStatus = lhs.status != .good && rhs.status == .good
        return ((lhs.name < rhs.name) && sameStatus) || differentStatus
    }
}
