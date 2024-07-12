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
            let stateText: String

            enum State: String, Codable {
                case operational
                case degraded
                case underMaintenance = "under_maintenance"
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
            case .underMaintenance:
                status = .maintenance
            }

            strongSelf.statusDescription = ServiceStatusDescription(
                status: status,
                message: response.page.stateText
            )
        }
    }
}
