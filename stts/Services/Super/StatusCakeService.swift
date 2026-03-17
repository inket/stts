//
//  StatusCakeService.swift
//  stts
//

import Foundation

class StatusCakeServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
    }

    let id: String
    let providerIdentifier = "statuscake"

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
        StatusCakeService(self)
    }
}

class StatusCakeService: Service {
    private enum StatusCakeStatus: String, ComparableStatus {
        case up = "Up"
        case down = "Down"

        var description: String {
            return rawValue
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .up:
                return .good
            case .down:
                return .major
            }
        }
    }

    let id: String
    let name: String
    let url: URL

    init(_ definition: StatusCakeServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let statusURL = URL(
            string: "https://app.statuscake.com/Workfloor/PublicReportHandler.php?PublicID=\(id)"
        )!
        let data = try await rawData(from: statusURL)

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let testData = json["TestData"] as? [[String: Any]]
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let statuses = testData.compactMap { $0["Status"] as? String }.compactMap(StatusCakeStatus.init(rawValue:))
        let highestStatus = statuses.max()

        statusDescription = ServiceStatusDescription(
            status: highestStatus?.serviceStatus ?? .undetermined,
            message: highestStatus?.description ?? "Unexpected response"
        )
    }
}
