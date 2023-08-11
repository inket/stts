//
//  Zendesk.swift
//  stts
//

import Foundation

private struct ZendeskIncidentsResponse: Codable {
    struct Incident: Codable {
        struct Attributes: Codable {
            let outage: Bool
            let resolvedAt: String?
        }

        let id: String
        let type: String
        let attributes: Attributes

        var status: ServiceStatus {
            if attributes.resolvedAt != nil {
                return .good
            } else if attributes.outage {
                return .major
            } else {
                return .minor
            }
        }
    }

    let data: [Incident]

    var globalStatus: ServiceStatus {
        data.map { $0.status }.max() ?? .undetermined
    }
}

class Zendesk: IndependentService {
    let url = URL(string: "https://status.zendesk.com")!

    override func updateStatus() async throws {
        let response = try await decoded(
            ZendeskIncidentsResponse.self,
            from: url.appendingPathComponent("api/ssp/incidents.json")
        )

        let status = response.globalStatus
        let message: String
        switch status {
        case .good:
            message = "No incidents"
        case .major, .minor:
            message = "Active incidents"
        default:
            message = "Unexpected response"
        }

        statusDescription = ServiceStatusDescription(status: status, message: message)
    }
}
