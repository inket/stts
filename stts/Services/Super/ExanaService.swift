//
//  ExanaService.swift
//  stts
//

import Foundation
import Kanna

class ExanaServiceDefinition: ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
    }

    /// Service ID
    let id: String
    let providerIdentifier = "exana"

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
        ExanaService(self)
    }
}

class ExanaService: Service {
    private enum ExanaStatus: String {
        case operational
        case monitoring

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .monitoring:
                return .maintenance
            }
        }
    }

    let id: String
    let name: String
    let url: URL

    init(_ definition: ExanaServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }

            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            guard let jwt = doc.css("meta[name=jwt]").first?["content"] else {
                return strongSelf._fail("Couldn't get authorization")
            }

            strongSelf.getStatus(authorization: jwt, callback: callback)
        }
    }

    func getStatus(authorization: String, callback: @escaping (ExanaService) -> Void) {
        let params: [String: Any] = [
            "method": "components.query",
            "params": [
                "serviceId": id
            ],
            "id": String.init(repeating: "a", count: 40),
            "jsonrpc": "2.0"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            return _fail("Couldn't serialize parameters for ExanaService request")
        }

        var request = URLRequest(url: URL(string: "https://statuspage.exana.io/api/components.query")!)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        loadData(with: request) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard let jsonRoot = json as? [String: Any],
                let result = jsonRoot["result"] as? [String: Any],
                let components = result["components"] as? [[String: Any]] else {
                return strongSelf._fail("Unexpected data")
            }

            var downComponents = [[String: Any]]()
            let componentStatuses: [ServiceStatus] = components.compactMap {
                guard let statusString = ($0["status"] as? String)?.lowercased() else { return nil }

                let resultStatus = ExanaStatus(rawValue: statusString)?.serviceStatus ?? .major
                if resultStatus != .good {
                    downComponents.append($0)
                }
                return resultStatus
            }

            let maxStatus: ServiceStatus = componentStatuses.max() ?? .undetermined

            let message: String
            switch maxStatus {
            case .good:
                message = "Operational"
            case .undetermined:
                message = "Unexpected response"
            default:
                message = downComponents.map { $0["name"] as? String }
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }

            strongSelf.statusDescription = ServiceStatusDescription(status: maxStatus, message: message)
        }
    }
}
