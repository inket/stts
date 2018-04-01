//
//  Slack.swift
//  stts
//

import Kanna

class Slack: Service {
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
            let statuses = imageURLs.map { selfie.status(from: $0) }

            self?.status = statuses.max() ?? .undetermined
            self?.message = doc.css("#current_status h1").first?.text ?? "Undetermined"
        }.resume()
    }
}

extension Slack {
    fileprivate func status(from imageURL: String) -> ServiceStatus {
        guard let lastPart = imageURL.split(separator: "/").last else {
            return .undetermined
        }
        let imageName = String(lastPart).lowercased()

        switch imageName {
        case "tableoutage.png":
            return .major
        case "tableincident.png":
            return .minor
        case "tablemaintenance.png":
            return .maintenance
        case "tablenotice.png":
            return .notice
        case "tablecheck.png":
            return .good
        default:
            return .undetermined
        }
    }
}
