//
//  UptimeDotComService.swift
//  stts
//

import Foundation

typealias UptimeDotComService = BaseUptimeDotComService & RequiredServiceProperties & RequiredUptimeDotComServices

protocol RequiredUptimeDotComServices {}

class BaseUptimeDotComService: BaseService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? UptimeDotComService else {
            fatalError("BaseUptimeDotComSErvice should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
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
