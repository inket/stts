//
//  Slack.swift
//  stts
//

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
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = try? HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            let serviceImages = doc.css("#services .service.header img")
            guard serviceImages.count > 0 else { return selfie._fail("Unexpected response") }

            let imageURLs = serviceImages.compactMap { $0["src"] }
            let statuses = imageURLs.compactMap { SlackStatus(rawValue: ($0.lowercased() as NSString).lastPathComponent) }

            self?.status = statuses.map { $0.serviceStatus }.max() ?? .undetermined
            self?.message = doc.css("#current_status h1").first?.text ?? "Undetermined"
        }.resume()
    }
}
