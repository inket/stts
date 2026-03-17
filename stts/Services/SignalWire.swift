//
//  SignalWire.swift
//  stts
//

import Foundation

class SignalWire: IndependentService {
    let url = URL(string: "https://status.signalwire.com")!

    override func updateStatus() async throws {
        let componentsURL = URL(string: "https://status.signalwire.com/api/components")!
        let components = try await decoded([Component].self, from: componentsURL)

        let affectedComponents = components.filter { $0.status.status != .good }

        let status: ServiceStatus
        let message: String
        if affectedComponents.isEmpty {
            status = .good
            message = "Operational"
        } else {
            status = affectedComponents.map { $0.status.status }.max() ?? .undetermined
            message = affectedComponents.map { "* \($0.name): \($0.status.rawValue)" }.joined(separator: "\n")
        }

        statusDescription = ServiceStatusDescription(status: status, message: message)
    }
}

private struct Component: Codable {
    enum ComponentStatus: String, Codable {
        case operational = "Operational"
        case underMaintenance = "Under Maintenance"
        case degradedPerformance = "Degraded Performance"
        case partialOutage = "Partial Outage"
        case majorOutage = "Major Outage"

        var status: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .underMaintenance:
                return .maintenance
            case .degradedPerformance, .partialOutage:
                return .minor
            case .majorOutage:
                return .major
            }
        }
    }

    let name: String
    let status: ComponentStatus
}
