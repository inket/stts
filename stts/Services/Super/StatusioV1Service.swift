//
//  StatusioV1Service.swift
//  stts
//

import Foundation

typealias StatusioV1Service = BaseStatusioV1Service & RequiredServiceProperties & RequiredStatusioV1Properties

protocol RequiredStatusioV1Properties {
    var statusPageID: String { get }
}

class BaseStatusioV1Service: BaseService {
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

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusioV1Service else { fatalError("BaseStatusioV1Service should not be used directly.") }

        let statusURL = URL(string: "https://api.status.io/1.0/status/\(realSelf.statusPageID)")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard
                let dict = json as? [String: Any],
                let resultJSON = dict["result"] as? [String: Any],
                let statusOverallJSON = resultJSON["status_overall"] as? [String: Any],
                let statusCode = statusOverallJSON["status_code"] as? Int,
                let status = StatusioV1Status(rawValue: statusCode),
                let statusMessage = statusOverallJSON["status"] as? String
            else {
                return selfie._fail("Unexpected data")
            }

            self?.status = status.serviceStatus
            self?.message = statusMessage
        }.resume()
    }
}
