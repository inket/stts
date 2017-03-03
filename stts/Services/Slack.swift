//
//  Slack.swift
//  stts
//

import Kanna

class Slack: Service {
    override var url: URL { return URL(string: "https://status.slack.com")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            guard let h1 = doc.css(".current_status > h1").first else { return selfie._fail("Unexpected response") }

            self?.status = selfie.status(from: h1)
            self?.message = h1.text ?? ""
        }.resume()
    }
}

extension Slack {
    fileprivate func status(from h1: XMLElement) -> ServiceStatus {
        guard let className = h1.className else { return .undetermined }

        if className.contains("happy_green") {
            return .good
        } else if className.contains("moscow_red") {
            return .major
        } else if className.contains("concerned_yellow") {
            return .minor
        } else {
            return .undetermined
        }
    }
}
