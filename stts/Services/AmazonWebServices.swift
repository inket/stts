//
//  AmazonWebServices.swift
//  stts
//

import Foundation

class AmazonWebServices: IndependentService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let dataURL = URL(string: "https://status.aws.amazon.com/data.json")!

        loadData(with: dataURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String: Any] else { return strongSelf._fail("Unexpected data") }

            guard let currentIssues = dict["current"] as? [[String: String]] else {
                return strongSelf._fail("Unexpected data")
            }

            self?.status = strongSelf.status(for: currentIssues)
            self?.message = strongSelf.message(for: currentIssues)
        }
    }
}

extension AmazonWebServices {
    fileprivate func status(for issues: [[String: String]]) -> ServiceStatus {
        if let mostRecentIssue = issues.first,
            let statusString = mostRecentIssue["status"], let status = Int(statusString) {
            switch status {
            case 0, 1: return .good
            case 2: return .minor
            case 3: return .major
            default: return .undetermined
            }
        } else {
            switch issues.count {
            case 0: return .good
            case 1: return .minor
            default: return .major
            }
        }
    }

    fileprivate func message(for issues: [[String: String]]) -> String {
        guard let firstIssue = issues.first else { return "No recent events" }

        return firstIssue["summary"] ?? "Click for details"
    }
}
