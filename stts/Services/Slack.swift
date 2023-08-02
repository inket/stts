//
//  Slack.swift
//  stts
//

import Foundation
import Kanna

class Slack: Service {
    private enum SlackStatus: String {
        case check = "tablecheck.png"
        case outage = "tableoutage.png"
        case incident = "tableincident.png"
        case maintenance = "tablemaintenance.png"
        case notice = "tablenotice.png"

        var serviceStatus: ServiceStatus {
            switch self {
            case .check:
                return .good
            case .outage:
                return .major
            case .incident:
                return .minor
            case .maintenance:
                return .maintenance
            case .notice:
                return .notice
            }
        }
    }

    let url = URL(string: "https://status.slack.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            let serviceImages = doc.css("#services .service.header img")
            guard serviceImages.count > 0 else { return strongSelf._fail("Unexpected response") }

            let imageURLs = serviceImages.compactMap { $0["src"] }
            let statuses = imageURLs.compactMap {
                SlackStatus(rawValue: ($0.lowercased() as NSString).lastPathComponent)
            }

            let status = statuses.map { $0.serviceStatus }.max() ?? .undetermined
            let message = doc.css("#current_status h1").first?.text ?? "Unexpected response"
            strongSelf.statusDescription = ServiceStatusDescription(status: status, message: message)
        }
    }
}
