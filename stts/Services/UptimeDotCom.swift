//
//  UptimeDotCom.swift
//  stts
//

import Foundation
import Kanna

class UptimeDotCom: Service {
    let name = "Uptime.com"
    let url = URL(string: "https://status.uptime.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let raw = String(data: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            if raw.range(of: "global_is_operational\": true") != nil {
                strongSelf.statusDescription = ServiceStatusDescription(
                    status: .good,
                    message: "All systems operational"
                )
            } else if raw.range(of: "global_is_operational\": false") != nil {
                strongSelf.statusDescription = ServiceStatusDescription(
                    status: .major,
                    message: "Some systems are experiencing problems"
                )
            } else {
                strongSelf.statusDescription = ServiceStatusDescription(
                    status: .undetermined,
                    message: "Unexpected response"
                )
            }
        }
    }
}
