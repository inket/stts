//
//  DigitalOcean.swift
//  stts
//

import Cocoa
import Kanna

class DigitalOcean: Service {
    override var url: URL { return URL(string: "https://status.digitalocean.com")! }

    override func updateStatus(callback: @escaping (Service) -> ()) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            self?.status = selfie.status(from: doc)
            self?.message = selfie.message(from: doc)
        }.resume()
    }
}

extension DigitalOcean {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        let iconClasses = document.css(".alerts-list .icon").flatMap { $0.className }

        if (iconClasses.filter { $0.range(of: "alert") != nil }).count > 0 {
            return .major
        } else if (iconClasses.filter { $0.range(of: "maintenance") != nil ||
                                        $0.range(of: "interim") != nil }).count > 0 {
            return .minor
        } else if (iconClasses.filter { $0.range(of: "success") != nil }).count > 0 {
            return .good
        } else {
            return .undetermined
        }
    }

    fileprivate func message(from document: HTMLDocument) -> String {
        return document.css(".alerts-list h2").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
