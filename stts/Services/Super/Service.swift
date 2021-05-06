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

public enum ServiceStatusMessage {
    static func from(_ error: Error?) -> String {
        if (error as NSError?)?.code == NSURLErrorNotConnectedToInternet {
            return "Internet connection offline."
        } else {
            return error?.localizedDescription ?? "Unexpected error"
        }
    }
}

protocol ComparableStatus: Comparable {
    var serviceStatus: ServiceStatus { get }
}

extension ComparableStatus {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.serviceStatus < rhs.serviceStatus
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

protocol ServiceCategory {
    /// The name of the category as it's displayed in the list
    var categoryName: String { get }

    /// The superclass of the sub services inside that category.
    var subServiceSuperclass: AnyObject.Type { get }
}

protocol SubService {} // Fits in a service submenu

public class BaseService: Loading {
    public var status: ServiceStatus = .undetermined
    var message: String = "Loading…"

    private var lastNotifiedStatus: ServiceStatus?

    public static func all() -> [BaseService] {
        guard let servicesPlist = Bundle.main.path(forResource: "services", ofType: "plist"),
            let services = NSDictionary(contentsOfFile: servicesPlist)?["services"] as? [String] else {
                fatalError("The services.plist file does not exist. The build phase script might have failed.")
        }

        return services.map(BaseService.named).compactMap { $0 }
    }

    public static func allWithoutSubServices() -> [BaseService] {
        all().filter { !($0 is SubService) }
    }

    static func named(_ name: String) -> BaseService? {
        return (NSClassFromString("stts.\(name)") as? Service.Type)?.init()
    }

    public required init() {}

    public func updateStatus(callback: @escaping (BaseService) -> Void) {}

    // swiftlint:disable:next identifier_name
    func _fail(_ error: Error?) {
        self.status = .undetermined
        self.message = ServiceStatusMessage.from(error)
    }

    // swiftlint:disable:next identifier_name
    func _fail(_ message: String) {
        self.status = .undetermined
        self.message = message
    }

    func notifyIfNecessary() {
        guard let realSelf = self as? Service else { fatalError("BaseService should not be used directly.") }

        let notifyBecauseDifferent =
            lastNotifiedStatus != nil
            && lastNotifiedStatus != .undetermined && status != .undetermined
            && lastNotifiedStatus != status

        if notifyBecauseDifferent && Preferences.shared.notifyOnStatusChange {
            let notification = NSUserNotification()
            let possessiveS = realSelf.name.hasSuffix("s") ? "'" : "'s"
            notification.title = "\(realSelf.name)\(possessiveS) status has changed"
            notification.informativeText = message

            NSUserNotificationCenter.default.deliver(notification)
        }

        lastNotifiedStatus = status
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

        return (lhs.name.localizedCompare(rhs.name) == .orderedAscending && sameStatus) || differentStatus
    }
}
