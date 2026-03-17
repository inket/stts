//
//  UptimeDotComService.swift
//  stts
//

import Foundation

typealias UptimeDotComService = BaseUptimeDotComService & RequiredServiceProperties & RequiredUptimeDotComServices

protocol RequiredUptimeDotComServices {}

class BaseUptimeDotComService: BaseIndependentService {
    override func updateStatus() async throws {
        guard let realSelf = self as? UptimeDotComService else {
            fatalError("BaseUptimeDotComService should not be used directly.")
        }

        let raw = try await rawString(from: realSelf.url)

        if raw.range(of: "global_is_operational\": true") != nil {
            statusDescription = ServiceStatusDescription(status: .good, message: "All systems operational")
        } else if raw.range(of: "global_is_operational\": false") != nil {
            statusDescription = ServiceStatusDescription(
                status: .major,
                message: "Some systems are experiencing problems"
            )
        } else {
            throw StatusUpdateError.parseError(nil)
        }
    }
}
