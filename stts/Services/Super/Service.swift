//
//  Service.swift
//  stts
//

import Foundation

public enum ServiceStatus: Int, Comparable {
    case undetermined
    case good
    case notice
    case maintenance
    case minor
    case major

    public static func < (lhs: ServiceStatus, rhs: ServiceStatus) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

typealias Service = BaseService & RequiredServiceProperties

protocol RequiredServiceProperties {
    var name: String { get }
    var url: URL { get }
}

extension RequiredServiceProperties {
    // Default implementation of the property `name` is to return the class name
    var name: String { return "\(type(of: self))" }
}

public class BaseService {
    public var status: ServiceStatus = .undetermined {
        didSet {
            if oldValue == .undetermined || status == .undetermined || oldValue == status {
                self.shouldNotify = false
            } else if Preferences.shared.notifyOnStatusChange {
                self.shouldNotify = true
            }
        }
    }
    var message: String = "Loading…"
    var shouldNotify = false

    public static func all() -> [BaseService] {
        guard let servicesPlist = Bundle.main.path(forResource: "services", ofType: "plist"),
            let services = NSDictionary(contentsOfFile: servicesPlist)?["services"] as? [String] else {
                fatalError("The services.plist file does not exist. The build phase script might have failed.")
        }

        return services.map(BaseService.named).compactMap { $0 }
    }

    static func named(_ name: String) -> BaseService? {
        return (NSClassFromString("stts.\(name)") as? Service.Type)?.init()
    }

    public required init() {}

    public func updateStatus(callback: @escaping (BaseService) -> Void) {}

    func _fail(_ error: Error?) {
        self.status = .undetermined
        self.message = error?.localizedDescription ?? "Unexpected error"
    }

    func _fail(_ message: String) {
        self.status = .undetermined
        self.message = message
    }

    func notifyIfNecessary() {
        guard let realSelf = self as? Service else { fatalError("BaseService should not be used directly.") }

        guard shouldNotify else { return }

        self.shouldNotify = false

        let notification = NSUserNotification()
        let possessiveS = realSelf.name.hasSuffix("s") ? "'" : "'s"
        notification.title = "\(realSelf.name)\(possessiveS) status has changed"
        notification.informativeText = message

        NSUserNotificationCenter.default.deliver(notification)
    }
}

extension BaseService: Equatable {
    public static func == (lhs: BaseService, rhs: BaseService) -> Bool {
        guard
            let lhs = lhs as? Service,
            let rhs = rhs as? Service
        else {
            fatalError("BaseService should not be used directly.")
        }

        return lhs.name == rhs.name
    }
}

extension BaseService: Comparable {
    public static func < (lhs: BaseService, rhs: BaseService) -> Bool {
        guard
            let lhs = lhs as? Service,
            let rhs = rhs as? Service
        else {
            fatalError("BaseService should not be used directly.")
        }

        let sameStatus = lhs.status == rhs.status
        let differentStatus =
            lhs.status != .good && lhs.status != .notice
            && rhs.status == .good || rhs.status == .notice
        return ((lhs.name < rhs.name) && sameStatus) || differentStatus
    }
}
