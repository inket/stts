//
//  LambStatusService.swift
//  stts
//

import Foundation

typealias LambStatusService = BaseLambStatusService & RequiredServiceProperties

class BaseLambStatusService: BaseService {
    // According to
    // https://github.com/ks888/LambStatus/blob/ba950df3241ac9143e03411d6c1a06d126cc0180/packages/frontend/src/utils/status.js#L1
    private enum LambStatus: String, Codable {
        case operational = "Operational"
        case underMaintenance = "Under Maintenance"
        case degradedPerformance = "Degraded Performance"
        case partialOutage = "Partial Outage"
        case majorOutage = "Major Outage"

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .underMaintenance:
                return .maintenance
            case .degradedPerformance,
                 .partialOutage:
                return .minor
            case .majorOutage:
                return .major
            }
        }
    }

    private struct LambComponent: Codable {
        let componentID: String
        let name: String
        let status: LambStatus
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? LambStatusService else { fatalError("BaseLambStatusService should not be used directly.") }

        let apiComponentsURL = realSelf.url.appendingPathComponent("api").appendingPathComponent("components")

        URLSession.shared.dataTask(with: apiComponentsURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard
                let components = try? JSONDecoder().decode([LambComponent].self, from: data),
                !components.isEmpty
            else {
                return strongSelf._fail("Unexpected response")
            }

            let worstComponent = components.max(by: { (one, two) -> Bool in
                one.status.serviceStatus < two.status.serviceStatus
            })! // We checked that it's not empty above

            self?.status = worstComponent.status.serviceStatus
            self?.message = worstComponent.status.rawValue
        }.resume()
    }
}
