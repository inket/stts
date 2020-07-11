//
//  SorryService.swift
//  stts
//

import Foundation

struct SorryServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case id
    }

    let name: String
    let url: URL
    let id: String

    var legacyIdentifier: String { name }
    var globalIdentifier: String { "sorry.\(id)" }

    func build() -> BaseService? {
        SorryService(self)
    }
}

class SorryService: Service {
    let id: String
    let name: String
    let url: URL

    init(_ definition: SorryServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let statusURL = URL(string: "https://api.sorryapp.com/v1/pages/\(id)/components")!

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard let components = (json as? [String: Any])?["response"] as? [[String: Any]] else {
                return strongSelf._fail("Unexpected data")
            }

            let statuses = components.compactMap { $0["state"] as? String }.compactMap(SorryStatus.init(rawValue:))

            let highestStatus = statuses.max()
            self?.status = highestStatus?.serviceStatus ?? .undetermined
            self?.message = highestStatus?.description ?? "Undetermined"
        }
    }
}

private enum SorryStatus: String, ComparableStatus {
    case operational
    case degraded
    case partiallyDegraded = "partially-degraded"

    var description: String {
        switch self {
        case .operational:
            return "Operational"
        case .degraded:
            return "Degraded"
        case .partiallyDegraded:
            return "Partially Degraded"
        }
    }
    var serviceStatus: ServiceStatus {
        switch self {
        case .operational:
            return .good
        case .degraded:
            return .major
        case .partiallyDegraded:
            return .minor
        }
    }
}
