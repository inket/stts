//
//  AppleStore.swift
//  stts
//

import Foundation

protocol AppleStoreService {
    var serviceName: String { get }
}

// AppleStore as in a store that holds the status of each of Apple's services, and not "Apple Store"
class AppleStore: Loading {
    let url: URL

    private var statuses: [String: (ServiceStatus, String)] = [:]
    private var loadErrorMessage: String?
    private var callbacks: [() -> Void] = []
    private var lastUpdateTime: TimeInterval = 0
    private var currentlyReloading: Bool = false

    init(url: String) {
        self.url = URL(string: url)!
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

            guard
                let jsonData = String(data: data, encoding: .utf8)?.innerJSONString.data(using: .utf8),
                let responseData = try? JSONDecoder().decode(AppleResponseData.self, from: jsonData)
            else {
                return self._fail("Unexpected data")
            }

            var serviceStatuses = [String: (ServiceStatus, String)]()

            responseData.services.forEach {
                if let worstEvent = $0.worstEvent {
                    serviceStatuses[$0.serviceName] = (worstEvent.serviceStatus, worstEvent.realStatus.rawValue)
                } else {
                    serviceStatuses[$0.serviceName] = (.good, "Available")
                }
            }

            self.statuses = serviceStatuses
            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: AppleStoreService) -> (ServiceStatus, String) {
        let status: ServiceStatus?
        let message: String?

        if service.serviceName == "*" {
            var lines: [String] = []
            var worstStatus: (ServiceStatus, String)?

            for (serviceName, serviceStatusAndDescription) in statuses {
                let serviceStatus = serviceStatusAndDescription.0
                let serviceStatusDescription = serviceStatusAndDescription.1

                if serviceStatus != .good {
                    lines.append("\(serviceName): \(serviceStatusDescription)")
                }

                if serviceStatus > worstStatus?.0 ?? .undetermined {
                    worstStatus = serviceStatusAndDescription
                }
            }

            status = worstStatus?.0
            message = lines.isEmpty ? worstStatus?.1 : lines.joined(separator: "\n")
        } else {
            let worstStatus: (ServiceStatus, String)? = statuses[service.serviceName]
            status = worstStatus?.0
            message = worstStatus?.1
        }

        return (status ?? .undetermined, message ?? loadErrorMessage ?? "Unexpected error")
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

struct AppleResponseData: Codable {
    struct Service: Codable {
        let serviceName: String
        let events: [Event]

        var worstEvent: Event? {
            return events.max { e1, e2 in e1.serviceStatus < e2.serviceStatus }
        }
    }

    enum EventStatus: String, Codable {
        case ongoing
        case resolved
        case upcoming
        case completed
    }

    enum EventType: String, Codable {
        case available = "Available"
        case outage = "Outage"
        case issue = "Issue"
        case performance = "Performance"
        case maintenance = "Maintenance"
    }

    struct Event: Codable {
        let statusType: EventType
        let eventStatus: EventStatus

        var realStatus: EventType {
            switch eventStatus {
            case .ongoing:
                return statusType
            case .resolved,
                 .upcoming,
                 .completed:
                return .available
            }
        }

        var serviceStatus: ServiceStatus {
            switch realStatus {
            case .available:
                return .good
            case .outage:
                return .major
            case .issue,
                 .performance:
                return .minor
            case .maintenance:
                return .maintenance
            }
        }
    }

    let services: [Service]
}
