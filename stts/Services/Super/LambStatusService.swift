//
//  LambStatusService.swift
//  stts
//

import Foundation

class LambStatusServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "lamb"

    func build() -> BaseService? {
        LambStatusService(self)
    }
}

class LambStatusService: Service {
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

    let name: String
    let url: URL

    init(_ definition: LambStatusServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let components = try await decoded(
            [LambComponent].self,
            from: url.appendingPathComponent("api").appendingPathComponent("components")
        )

        guard !components.isEmpty else {
            throw StatusUpdateError.decodingError(nil)
        }

        let worstComponent = components.max(by: { (one, two) -> Bool in
            one.status.serviceStatus < two.status.serviceStatus
        })! // We checked that it's not empty above

        statusDescription = ServiceStatusDescription(
            status: worstComponent.status.serviceStatus,
            message: worstComponent.status.rawValue
        )
    }
}
