//
//  Netlify.swift
//  stts
//

import Kanna

class Netlify: Service {
    override var url: URL { return URL(string: "https://netlifystatus.com")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            self?.status = selfie.status(from: doc)
            self?.message = doc.css("#days-since-latest").first?.text ?? ""
        }.resume()
    }
}

extension Netlify {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        let badges = document.css(".system-status-badge")

        for badge in badges {
            guard let className = badge.className else { continue }

            if className.contains("danger") {
                return .major
            } else if className.contains("warning") {
                return .minor
            }
        }

        return .good
    }
}
