//
//  StatusioV1Service.swift
//  stts
//

import Foundation

struct StatusioV1ServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case id
        case oldName = "old_name"
    }

    let name: String
    let url: URL
    let id: String
    let oldName: String?

    var legacyIdentifier: String { oldName ?? name }
    var globalIdentifier: String { "statusiov1.\(id)" }

    func build() -> BaseService? {
        StatusioV1Service(self)
    }
}

class StatusioV1Service: Service {
    let id: String
    let name: String
    let url: URL
    let oldName: String?

    init(_ definition: StatusioV1ServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
        oldName = definition.oldName
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

            self?.status = status.serviceStatus
            self?.message = statusMessage
        }
    }
}

private enum StatusioV1Status: Int {
    case operational = 100
    case degradedPerformance = 300
    case partialServiceDisruption = 400
    case serviceDisruption = 500
    case securityEvent = 600

    var serviceStatus: ServiceStatus {
        switch self {
        case .operational:
            return .good
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
