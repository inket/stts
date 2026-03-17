//
//  AppleStore.swift
//  stts
//

import Foundation

protocol AppleStoreService {
    var serviceName: String { get }
}

// AppleStore as in a store that holds the status of each of Apple's services, and not "Apple Store"
class AppleStore: ServiceStore<[String: (ServiceStatus, String)]> {
    let url: URL

    init(url: String) {
        self.url = URL(string: url)!
    }

    override func retrieveUpdatedState() async throws -> [String: (ServiceStatus, String)] {
        let raw = try await rawString(from: url)

        guard let jsonData = raw.innerJSONString.data(using: .utf8) else {
            throw StatusUpdateError.decodingError(nil)
        }

        let responseData: AppleResponseData
        do {
            responseData = try JSONDecoder().decode(AppleResponseData.self, from: jsonData)
        } catch {
            throw StatusUpdateError.decodingError(error)
        }

        var serviceStatuses = [String: (ServiceStatus, String)]()

        responseData.services.forEach {
            if let worstEvent = $0.worstEvent {
                serviceStatuses[$0.serviceName] = (worstEvent.serviceStatus, worstEvent.realStatus.rawValue)
            } else {
                serviceStatuses[$0.serviceName] = (.good, "Available")
            }
        }

        return serviceStatuses
    }

    func updatedStatus(for service: AppleStoreService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        let status: ServiceStatus?
        let message: String?

        if service.serviceName == "*" {
            var lines: [String] = []
            var worstStatus: (ServiceStatus, String)?

            for (serviceName, serviceStatusAndDescription) in updatedState {
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
            let worstStatus: (ServiceStatus, String)? = updatedState[service.serviceName]
            status = worstStatus?.0
            message = worstStatus?.1
        }

        return ServiceStatusDescription(
            status: status ?? .undetermined,
            message: message ?? loadErrorMessage ?? "Unexpected error"
        )
    }
}

private struct AppleResponseData: Codable {
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
