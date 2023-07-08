//
//  ExanaService.swift
//  stts
//

import Foundation
import Kanna

typealias ExanaService = BaseExanaService & RequiredServiceProperties & RequiredExanaProperties

protocol RequiredExanaProperties {
    var serviceID: String { get }
}

class BaseExanaService: BaseService {
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

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? ExanaService else { fatalError("BaseExanaService should not be used directly.") }

        loadData(with: realSelf.url) { [weak self] data, _, error in
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

    func getStatus(authorization: String, callback: @escaping (BaseExanaService) -> Void) {
        guard let realSelf = self as? ExanaService else { fatalError("BaseExanaService should not be used directly.") }

        let params: [String: Any] = [
            "method": "components.query",
            "params": [
                "serviceId": realSelf.serviceID
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
            strongSelf.status = maxStatus

            switch maxStatus {
            case .good:
                strongSelf.message = "Operational"
            case .undetermined:
                strongSelf.message = "Undetermined"
            default:
                strongSelf.message = downComponents.map { $0["name"] as? String }
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
        }
    }
}
