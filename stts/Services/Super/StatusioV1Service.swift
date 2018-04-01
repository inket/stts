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
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusioV1Service else { fatalError("BaseStatusioV1Service should not be used directly.") }

        let statusURL = URL(string: "https://api.status.io/1.0/status/\(realSelf.statusPageID)")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String: Any],
                let resultJSON = dict["result"] as? [String: Any],
                let statusOverallJSON = resultJSON["status_overall"] as? [String: Any],
                let statusCode = statusOverallJSON["status_code"] as? Int,
                let statusMessage = statusOverallJSON["status"] as? String
                else {
                    return selfie._fail("Unexpected data")
            }

            switch statusCode {
            case 100: self?.status = .good  // Operational
            case 300: self?.status = .minor // Degraded Performance
            case 400: self?.status = .minor // Partial Service Disruption
            case 500: self?.status = .major // Service Disruption
            case 600: self?.status = .major // Security Event
            default: self?.status = .undetermined
            }

            self?.message = statusMessage
        }.resume()
    }
}
