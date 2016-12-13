//
//  AmazonWebServices.swift
//  stts
//

import Cocoa

class AmazonWebServices: Service {
    override var name: String { return "Amazon Web Services" }
    override var url: URL { return URL(string: "https://status.aws.amazon.com")! }

    override func updateStatus(callback: @escaping (Service) -> ()) {
        let dataURL = URL(string: "https://status.aws.amazon.com/data.json")!

        URLSession.shared.dataTask(with: dataURL) { [weak self] data, response, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String : Any] else { return selfie._fail("Unexpected data") }

            guard let currentIssues = dict["current"] as? [[String : String]] else {
                return selfie._fail("Unexpected data")
            }

            self?.status = selfie.status(for: currentIssues)
            self?.message = selfie.message(for: currentIssues)
        }.resume()
    }
}

extension AmazonWebServices {
    fileprivate func status(for issues: [[String : String]]) -> ServiceStatus {
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

    fileprivate func message(for issues: [[String : String]]) -> String {
        guard let firstIssue = issues.first else { return "No recent events" }

        return firstIssue["summary"] ?? "Click for details"
    }
}
