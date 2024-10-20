//
//  Broadcom.swift
//  stts
//

import Foundation

class Broadcom: Service {
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

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let url = URL(string: "https://status.broadcom.com/api/v1/status")!

        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
                return strongSelf._fail("Couldn't parse response")
            }

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

            strongSelf.statusDescription = ServiceStatusDescription(
                status: status,
                message: stateText
            )
        }
    }
}
