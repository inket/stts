//
//  CachetService.swift
//  stts
//

import Foundation

class CachetServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "cachet"

    func build() -> BaseService? {
        CachetService(self)
    }
}

class CachetService: Service {
    private enum ComponentStatus: Int, ComparableStatus {
        // https://docs.cachethq.io/docs/component-statuses
        case operational = 1
        case performanceIssues = 2
        case partialOutage = 3
        case majorOutage = 4

        var description: String {
            switch self {
            case .operational:
                return "Operational"
            case .performanceIssues:
                return "Performance Issues"
            case .partialOutage:
                return "Partial Outage"
            case .majorOutage:
                return "Major Outage"
            }
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .performanceIssues:
                return .notice
            case .partialOutage:
                return .minor
            case .majorOutage:
                return .major
            }
        }
    }

    let name: String
    let url: URL

    init(_ definition: CachetServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let apiComponentsURL = url.appendingPathComponent("api/v1/components")
        let data = try await self.rawData(from: url)

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        guard
            let components = (json as? [String: Any])?["data"] as? [[String: Any]],
            !components.isEmpty
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let worstStatus = components
            .compactMap({ $0["status"] as? Int })
            .compactMap(ComponentStatus.init(rawValue:))
            .max()

        statusDescription = ServiceStatusDescription(
            status: worstStatus?.serviceStatus ?? .undetermined,
            message: worstStatus?.description ?? "Unexpected response"
        )
    }
}
