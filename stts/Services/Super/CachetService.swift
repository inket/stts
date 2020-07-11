//
//  CachetService.swift
//  stts
//

import Foundation

struct CachetServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
    }

    let name: String
    let url: URL

    var legacyIdentifier: String { name }
    var globalIdentifier: String { "cachet.\(alphanumericName)" }

    func build() -> BaseService? {
        CachetService(self)
    }
}

class CachetService: BaseService {
    let name: String
    let url: URL

    init(_ definition: CachetServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let apiComponentsURL = url.appendingPathComponent("api/v1/components")

        loadData(with: apiComponentsURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let components = (json as? [String: Any])?["data"] as? [[String: Any]] else {
                return strongSelf._fail("Unexpected data")
            }

            guard !components.isEmpty else { return strongSelf._fail("Unexpected data") }

            let statuses = components.compactMap({ $0["status"] as? Int }).compactMap(ComponentStatus.init(rawValue:))

            let highestStatus = statuses.max()
            strongSelf.status = highestStatus?.serviceStatus ?? .undetermined
            strongSelf.message = highestStatus?.description ?? "Undetermined"
        }
    }
}

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
