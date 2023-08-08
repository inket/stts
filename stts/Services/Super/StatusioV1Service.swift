//
//  StatusioV1Service.swift
//  stts
//

import Foundation

class StatusioV1ServiceDefinition: ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
    }

    let id: String
    let providerIdentifier = "statusiov1"

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
        StatusioV1Service(self)
    }
}

class StatusioV1Service: Service {
    private enum StatusioV1Status: Int {
        case operational = 100
        case plannedMaintenance = 200
        case degradedPerformance = 300
        case partialServiceDisruption = 400
        case serviceDisruption = 500
        case securityEvent = 600

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .plannedMaintenance:
                return .maintenance
            case .degradedPerformance:
                return .minor
            case .partialServiceDisruption:
                return .minor
            case .serviceDisruption,
                 .securityEvent:
                return .major
            }
        }
    }

    let id: String
    let name: String
    let url: URL

    init(_ definition: StatusioV1ServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let statusURL = URL(string: "https://api.status.io/1.0/status/\(id)")!

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard
                let dict = json as? [String: Any],
                let resultJSON = dict["result"] as? [String: Any],
                let statusOverallJSON = resultJSON["status_overall"] as? [String: Any],
                let statusCode = statusOverallJSON["status_code"] as? Int,
                let status = StatusioV1Status(rawValue: statusCode),
                let statusMessage = statusOverallJSON["status"] as? String
            else {
                return strongSelf._fail("Unexpected data")
            }

            strongSelf.statusDescription = ServiceStatusDescription(
                status: status.serviceStatus,
                message: statusMessage
            )
        }
    }
}
