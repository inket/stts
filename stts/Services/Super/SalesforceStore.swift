//
//  SalesforceStore.swift
//  SalesforceStore
//

import Foundation

protocol SalesforceStoreService {
    var key: String { get }
    var location: String { get }
}

class SalesforceStore: Loading {
    let key: String

    private var url: URL {
        URL(string: "https://api.status.salesforce.com/v1/instances/status/preview?products=\(key)")!
    }

    private var statuses: [String: ServiceStatus] = [:] // [location: status]
    private var loadErrorMessage: String?
    private var callbacks: [() -> Void] = []
    private var lastUpdateTime: TimeInterval = 0
    private var currentlyReloading: Bool = false

    init(key: String) {
        self.key = key
    }

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

            guard let instances = try? JSONDecoder().decode([SalesforceResponseData.Instance].self, from: data) else {
                return self._fail("Unexpected data")
            }

            var serviceStatuses = [String: ServiceStatus]()

            instances.forEach { instance in
                var locationStatus = serviceStatuses[instance.location] ?? .undetermined
                locationStatus = [locationStatus, instance.status.serviceStatus].max() ?? .undetermined
                serviceStatuses[instance.location] = locationStatus

                var allLocationsStatus = serviceStatuses["*"] ?? .undetermined
                allLocationsStatus = [allLocationsStatus, instance.status.serviceStatus].max() ?? .undetermined
                serviceStatuses["*"] = allLocationsStatus
            }

            self.statuses = serviceStatuses
            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: SalesforceStoreService) -> (ServiceStatus, String) {
        let status = statuses[service.location] ?? .undetermined
        let message: String

        switch status {
        case .good:
            message = "Available"
        case .minor:
            message = "Performance Degradation"
        case .major:
            message = "Service Disruption"
        case .maintenance:
            message = "Maintenance"
        case .notice:
            message = "Notice"
        case .undetermined:
            message = loadErrorMessage ?? "Unexpected error"
        }

        return (status, message)
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

private struct SalesforceResponseData: Codable {
    struct Instance: Codable {
        enum CodingKeys: String, CodingKey {
            case location
            case status
        }

        let location: String
        let status: Status
    }

    enum Status: String, Codable {
        case ok = "OK"
        case maintenanceNonCore = "MAINTENANCE_NONCORE"
        case maintenanceCore = "MAINTENANCE_CORE"
        case minorNonCore = "MINOR_INCIDENT_NONCORE"
        case minorCore = "MINOR_INCIDENT_CORE"
        case majorNonCore = "MAJOR_INCIDENT_NONCORE"
        case majorCore = "MAJOR_INCIDENT_CORE"

        var serviceStatus: ServiceStatus {
            switch self {
            case .ok: return .good
            case .maintenanceNonCore, .maintenanceCore: return .maintenance
            case .minorNonCore, .minorCore, .majorNonCore: return .minor
            case .majorCore: return .major
            }
        }
    }
}
