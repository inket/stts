//
//  SorryService.swift
//  stts
//

import Foundation

class SorryServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
    }

    let id: String
    let providerIdentifier = "sorry"

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)

        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
    }

    func build() -> BaseService? {
        SorryService(self)
    }
}

class SorryService: Service {
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

    let id: String
    let name: String
    let url: URL

    init(_ definition: SorryServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let statusURL = URL(string: "https://api.sorryapp.com/v1/pages/\(id)/components")!
        let data = try await rawData(from: statusURL)

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let components = json["response"] as? [[String: Any]]
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let statuses = components.compactMap { $0["state"] as? String }.compactMap(SorryStatus.init(rawValue:))

        let worstStatus = statuses.max()
        statusDescription = ServiceStatusDescription(
            status: worstStatus?.serviceStatus ?? .undetermined,
            message: worstStatus?.description ?? "Unexpected response"
        )
    }
}
