//
//  AdobeStore.swift
//  stts
//

import Foundation

protocol AdobeStoreService {
    var id: String { get }
}

private enum Status: String {
    case opened
    case started
    case updated
    case reopened
    case discovery
    case scheduled
    case closed
    case canceled
    case completed
    case dismissed

    var isOpen: Bool {
        switch self {
        case .opened, .started, .updated, .reopened, .discovery, .scheduled:
            return true
        case .closed, .canceled, .completed, .dismissed:
            return false
        }
    }

    init?(_ string: String) {
        self.init(rawValue: string.lowercased())
    }
}

private enum Severity: String {
    case major
    case minor
    case potential
    case maintenance
    case trivial

    var status: ServiceStatus {
        switch self {
        case .major: return .major
        case .minor: return .minor
        case .maintenance: return .maintenance
        case .potential, .trivial: return .notice
        }
    }

    init?(_ string: String) {
        self.init(rawValue: string.lowercased())
    }
}

private struct StatusEvents {
    struct Cloud {
        let id: String
        let name: String

        static func clouds(from dictionary: [String: Any]) -> [Self] {
            dictionary.compactMap { _, object in
                guard let dict = object as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let name = dict["name"] as? String
            else { return nil }

            self.id = id
            self.name = name
        }
    }

    struct MaintenanceProduct {
        let id: String
        let name: String

        static func products(from dictionary: [String: Any]) -> [Self] {
            dictionary.compactMap { _, object in
                guard let dict = object as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let name = dict["name"] as? String
            else { return nil }

            self.id = id
            self.name = name
        }
    }

    struct IncidentProduct {
        let id: String
        let name: String
        let history: [IncidentHistoryItem]

        static func products(from dictionary: [String: Any]) -> [Self] {
            dictionary.compactMap { _, object in
                guard let dict = object as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let historyDictionary = dict["history"] as? [String: Any]
            else { return nil }

            self.id = id
            self.name = name
            self.history = IncidentHistoryItem.historyItems(from: historyDictionary)
        }
    }

    struct IncidentHistoryItem {
        let id: String
        let status: Status
        let severity: Severity

        static func historyItems(from dictionary: [String: Any]) -> [Self] {
            // We want them to be sorted by date and in this case the keys are timestamps
            let sortedKeys = dictionary.keys.sorted()

            return sortedKeys.compactMap { (key: String) -> Self? in
                guard let dict = dictionary[key] as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let status = Status(dict["status"] as? String ?? ""),
                let severity = Severity(dict["severity"] as? String ?? "")
            else { return nil }

            self.id = id
            self.status = status
            self.severity = severity
        }
    }

    struct MaintenanceEvent {
        let id: String
        let status: Status

        let clouds: [Cloud]
        let products: [MaintenanceProduct]

        static func events(from dictionary: [String: Any]) -> [Self] {
            dictionary.compactMap { _, object in
                guard let dict = object as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let status = Status(dict["status"] as? String ?? ""),
                let cloudsDictionary = dict["clouds"] as? [String: Any],
                let productsDictionary = dict["products"] as? [String: Any]
            else { return nil }

            self.id = id
            self.status = status
            self.clouds = Cloud.clouds(from: cloudsDictionary)
            self.products = MaintenanceProduct.products(from: productsDictionary)
        }
    }

    struct IncidentEvent {
        let id: String

        let clouds: [Cloud]
        let products: [IncidentProduct]

        static func events(from dictionary: [String: Any]) -> [Self] {
            dictionary.compactMap { _, object in
                guard let dict = object as? [String: Any] else { return nil }
                return Self(dict)
            }
        }

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let cloudsDictionary = dict["clouds"] as? [String: Any],
                let productsDictionary = dict["products"] as? [String: Any]
            else { return nil }

            self.id = id
            self.clouds = Cloud.clouds(from: cloudsDictionary)
            self.products = IncidentProduct.products(from: productsDictionary)
        }
    }

    let maintenanceEvents: [MaintenanceEvent]
    let incidentEvents: [IncidentEvent]

    init?(_ data: Data) {
        guard
            let structure = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let maintenanceEventDictionary = structure["maintenanceEvent"] as? [String: Any],
            let maintenanceDictionary = maintenanceEventDictionary["maintenance"] as? [String: Any],
            let incidentEventDictionary = structure["incidentEvent"] as? [String: Any],
            let incidentsDictionary = incidentEventDictionary["incidents"] as? [String: Any]
        else {
            return nil
        }

        maintenanceEvents = MaintenanceEvent.events(from: maintenanceDictionary)
        incidentEvents = IncidentEvent.events(from: incidentsDictionary)
    }
}

class AdobeStore: Loading {
    let url = URL(string: "https://data.status.adobe.com/adobestatus/StatusEvents")!
    private var statuses: [String: ServiceStatus] = [:]
    private var loadErrorMessage: String?
    private var callbacks: [() -> Void] = []
    private var lastUpdateTime: TimeInterval = 0
    private var currentlyReloading: Bool = false

    func loadStatus(_ callback: @escaping () -> Void) {
        callbacks.append(callback)

        guard !currentlyReloading else { return }

        // Throttling to prevent multiple requests if the first one finishes too quickly
        guard Date.timeIntervalSinceReferenceDate - lastUpdateTime >= 3 else { return clearCallbacks() }

        currentlyReloading = true

        loadData(with: url) { data, _, error in
            defer {
                self.currentlyReloading = false
                self.clearCallbacks()
            }

            self.statuses = [:]

            guard let data = data else { return self._fail(error) }

            guard let statusEvents = StatusEvents(data) else {
                return self._fail("Unexpected data")
            }

            var statuses: [String: ServiceStatus] = [:]

            statusEvents.maintenanceEvents.forEach { maintenanceEvent in
                if maintenanceEvent.status == .started {
                    let affectedIDs = maintenanceEvent.clouds.map { $0.id } + maintenanceEvent.products.map { $0.id }

                    affectedIDs.forEach {
                        statuses[$0] = .maintenance
                    }
                }
            }

            statusEvents.incidentEvents.forEach { incidentEvent in
                let affectedCloudIDs = incidentEvent.clouds.map { $0.id }

                incidentEvent.products.forEach { incidentProduct in
                    guard let mostRecentUpdate = incidentProduct.history.last else { return }

                    if mostRecentUpdate.status.isOpen {
                        let status = mostRecentUpdate.severity.status
                        let affectedIDs = affectedCloudIDs + [incidentProduct.id]

                        affectedIDs.forEach {
                            if let addedStatus = statuses[$0] {
                                statuses[$0] = max(addedStatus, status)
                            } else {
                                statuses[$0] = status
                            }
                        }
                    }
                }
            }

            self.statuses = statuses
            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: AdobeStoreService) -> ServiceStatusDescription {
        let status = statuses[service.id]

        switch status {
        case .good?: return ServiceStatusDescription(status: .good, message: "Available")
        case .minor?: return ServiceStatusDescription(status: .minor, message: "Minor issue(s)")
        case .major?: return ServiceStatusDescription(status: .major, message: "Major issue(s)")
        case .notice?: return ServiceStatusDescription(status: .notice, message: "Potential issue(s)")
        case .maintenance?: return ServiceStatusDescription(status: .maintenance, message: "Maintenance")
        case .some(.undetermined): return ServiceStatusDescription(
            status: .undetermined,
            message: loadErrorMessage ?? "Unexpected error"
        )
        case .none: return ServiceStatusDescription(status: .good, message: "Available")
        }
    }

    private func clearCallbacks() {
        callbacks.forEach { $0() }
        callbacks = []
    }

    private func _fail(_ error: Error?) {
        _fail(ServiceStatusMessage.from(error))
    }

    private func _fail(_ message: String) {
        loadErrorMessage = message
        lastUpdateTime = 0
    }
}
