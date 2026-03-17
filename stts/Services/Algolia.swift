//
//  Algolia.swift
//  stts
//

import Foundation
import Kanna

class Algolia: IndependentService {
    private enum AlgoliaStatus: String {
        case operational
        case majorOutage = "major_outage"
        case degradedPerformance = "degraded_performance"
        case partialOutage = "partial_outage"

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .majorOutage:
                return .major
            case .degradedPerformance,
                 .partialOutage:
                return .minor
            }
        }

        var statusMessage: String {
            switch self {
            case .operational:
                return "Operational"
            case .majorOutage:
                return "Major outage"
            case .degradedPerformance:
                return "Degraded performance"
            case .partialOutage:
                return "Partial outage"
            }
        }

        var serviceDescription: ServiceStatusDescription {
            ServiceStatusDescription(status: serviceStatus, message: statusMessage)
        }
    }

    let url = URL(string: "https://status.algolia.com")!

    override func updateStatus() async throws {
        let apiURL = URL(string: "https://status.algolia.com/2/status/service/all/period/current")!
        let data = try await rawData(from: apiURL)

        guard
            let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let statusDict = dict["global"] as? [String: Any],
            let statusString = statusDict["status"] as? String,
            let status = AlgoliaStatus(rawValue: statusString)
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        statusDescription = status.serviceDescription
    }
}
