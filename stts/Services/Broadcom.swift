//
//  Broadcom.swift
//  stts
//

import Foundation

class Broadcom: IndependentService {
    let url = URL(string: "https://status.broadcom.com")!

    private struct Response: Codable {
        let page: Page

        struct Page: Codable {
            let state: State
            let stateText: String? // null when under maintenance

            enum State: String, Codable {
                case operational
                case degraded
                case underMaintenanceOfficial = "under_maintenance" // as defined in their API spec
                case underMaintenanceActual = "under-maintenance" // as actually delivered by their API
            }

            enum CodingKeys: String, CodingKey {
                case state
                case stateText = "state_text"
            }
        }
    }

    override func updateStatus() async throws {
        let apiURL = URL(string: "https://status.broadcom.com/api/v1/status")!
        let response = try await decoded(Response.self, from: apiURL)

        let status: ServiceStatus
        switch response.page.state {
        case .operational:
            status = .good
        case .degraded:
            status = .major
        case .underMaintenanceOfficial, .underMaintenanceActual:
            status = .maintenance
        }

        let stateText: String
        if let text = response.page.stateText {
            stateText = text
        } else {
            switch status {
            case .good:
                stateText = "All systems are go!"
            case .maintenance:
                stateText = "Under maintenance"
            case .major:
                stateText = "Degraded"
            default:
                stateText = "No status description"
            }
        }

        statusDescription = ServiceStatusDescription(status: status, message: stateText)
    }
}
