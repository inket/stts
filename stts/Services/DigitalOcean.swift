//
//  DigitalOcean.swift
//  stts
//

import Kanna

class DigitalOcean: Service {
    override var url: URL { return URL(string: "https://status.digitalocean.com")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
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
        guard document.css(".page-status.status-none").count == 0 else { return .good }

        let unresolvedIncidentClasses = document.css(".unresolved-incident").flatMap { $0.className }

        if (unresolvedIncidentClasses.filter { $0.range(of: "impact-critical") != nil || $0.range(of: "impact-major") != nil }).count > 0 {
            return .major
        } else if (unresolvedIncidentClasses.filter { $0.range(of: "impact-minor") != nil }).count > 0 {
            return .minor
        } else if (unresolvedIncidentClasses.filter { $0.range(of: "impact-maintenance") != nil }).count > 0 {
            return .maintenance
        } else {
            return .undetermined
        }
    }

    fileprivate func message(from document: HTMLDocument) -> String {
        let statusTitle = document.css(".page-status .status").first?.text
        let incidentTitle = document.css(".unresolved-incident .incident-title .title").first?.text

        return (statusTitle ?? incidentTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
