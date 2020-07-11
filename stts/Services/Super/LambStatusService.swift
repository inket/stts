//
//  LambStatusService.swift
//  stts
//

import Foundation

struct LambStatusServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
    }

    let name: String
    let url: URL

    var legacyIdentifier: String { name }
    var globalIdentifier: String { "lamb.\(alphanumericName)" }

    func build() -> BaseService? {
        LambStatusService(self)
    }
}

class LambStatusService: BaseService {
    let name: String
    let url: URL

    init(_ definition: LambStatusServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let apiComponentsURL = url.appendingPathComponent("api").appendingPathComponent("components")

        loadData(with: apiComponentsURL) { [weak self] data, _, error in
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
        }
    }
}

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
