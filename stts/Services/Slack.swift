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

            let serviceImages = doc.css("#services .service.header img")
            guard serviceImages.count > 0 else { return selfie._fail("Unexpected response") }
            let imageURLs = serviceImages.flatMap { $0["src"] }

            var resultStatus: ServiceStatus = .undetermined
            var resultMessage = "Undetermined"

            for url in imageURLs {
                guard resultStatus != .major else { break } // No need to check the rest if major

                guard let lastPart = url.split(separator: "/").last else { continue }
                let imageName = String(lastPart).lowercased()

                let (thisStatus, thisMessage) = selfie.status(from: imageName)

                if thisStatus >= resultStatus {
                    resultStatus = thisStatus
                    resultMessage = thisMessage
                }
            }

            self?.status = resultStatus
            self?.message = resultMessage
        }.resume()
    }
}

extension Slack {
    fileprivate func status(from imageName: String) -> (ServiceStatus, String) {
        switch imageName {
        case "tableoutage.png":
            return (.major, "Outage")
        case "tableincident.png":
            return (.minor, "Incident")
        case "tablemaintenance.png":
            return (.maintenance, "Maintenance")
        case "tablenotice.png":
            return (.notice, "[!] Notice Available")
        case "tablecheck.png":
            return (.good, "No Issues")
        default:
            return (.undetermined, "Undetermined")
        }
    }
}
