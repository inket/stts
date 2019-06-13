//
//  Netlify.swift
//  stts
//

import Kanna

class Netlify: Service {
    let url = URL(string: "https://netlifystatus.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.sharedWithoutCaching.dataTask(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }

            self?.status = strongSelf.status(from: doc)
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
