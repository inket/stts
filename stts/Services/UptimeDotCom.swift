//
//  UptimeDotCom.swift
//  stts
//

import Foundation
import Kanna

class UptimeDotCom: IndependentService {
    let name = "Uptime.com"
    let url = URL(string: "https://status.uptime.com")!

    override func updateStatus() async throws {
        let raw = try await rawString(from: url)

        if raw.range(of: "global_is_operational\": true") != nil {
            statusDescription = ServiceStatusDescription(
                status: .good,
                message: "All systems operational"
            )
        } else if raw.range(of: "global_is_operational\": false") != nil {
            statusDescription = ServiceStatusDescription(
                status: .major,
                message: "Some systems are experiencing problems"
            )
        } else {
            statusDescription = ServiceStatusDescription(
                status: .undetermined,
                message: "Unexpected response"
            )
        }
    }
}
