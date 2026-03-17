//
//  ExanaService.swift
//  stts
//

import Foundation
import Kanna

class ExanaServiceDefinition: CodableServiceDefinition, ServiceDefinition {
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

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        guard let jwt = doc.css("meta[name=jwt]").first?["content"] else {
            throw StatusUpdateError.custom("Couldn't get authorization")
        }

        try await getStatus(authorization: jwt)
    }

    func getStatus(authorization: String) async throws {
        let params: [String: Any] = [
            "method": "components.query",
            "params": [
                "serviceId": id
            ],
            "id": String.init(repeating: "a", count: 40),
            "jsonrpc": "2.0"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            throw StatusUpdateError.custom("Couldn't serialize parameters for ExanaService request")
        }

        var request = URLRequest(url: URL(string: "https://statuspage.exana.io/api/components.query")!)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        let data = try await rawData(for: request)

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let jsonRoot = json as? [String: Any],
            let result = jsonRoot["result"] as? [String: Any],
            let components = result["components"] as? [[String: Any]]
        else {
            throw StatusUpdateError.decodingError(nil)
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

        statusDescription = ServiceStatusDescription(status: maxStatus, message: message)
    }
}
