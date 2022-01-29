//
//  Algolia.swift
//  stts
//

import Kanna

class Algolia: Service {
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
    }

    let url = URL(string: "https://status.algolia.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let apiURL = URL(string: "https://status.algolia.com/2/status/service/all/period/current")!

        loadData(with: apiURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard
                let dict = json as? [String: Any],
                let statusDict = dict["global"] as? [String: Any],
                let statusString = statusDict["status"] as? String,
                let status = AlgoliaStatus(rawValue: statusString)
            else { return strongSelf._fail("Unexpected data") }

            self?.status = status.serviceStatus
            self?.message = status.statusMessage
        }
    }
}
