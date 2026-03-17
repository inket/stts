//
//  StatusCastService.swift
//  stts
//

import Foundation
import Kanna

class StatusCastServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "statuscast"

    func build() -> BaseService? {
        StatusCastService(self)
    }
}

class StatusCastService: Service {
    private enum Status: String, CaseIterable {
        case available
        case unavailable
        case informational
        case monitored
        case identified
        case investigating
        case degraded
        case maintenance

        var serviceStatus: ServiceStatus {
            switch self {
            case .available:
                return .good
            case .unavailable:
                return .major
            case .informational, .monitored, .identified:
                return .notice
            case .investigating, .degraded:
                return .minor
            case .maintenance:
                return .maintenance
            }
        }
    }

    let name: String
    let url: URL

    init(_ definition: StatusCastServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        let statuses: [(ServiceStatus, String?)] = doc.css(".status-list-component-status-text").map { element in
            for status in Status.allCases {
                if element.className?.contains("component-\(status.rawValue)") == true {
                    return (
                        status.serviceStatus,
                        element.innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }

            return (.undetermined, nil)
        }

        guard let worstStatus = statuses.max(by: { $0.0 < $1.0 }) else {
            throw StatusUpdateError.decodingError(nil)
        }

        statusDescription = ServiceStatusDescription(
            status: worstStatus.0,
            message: worstStatus.1 ?? "Unexpected response"
        )
    }
}
