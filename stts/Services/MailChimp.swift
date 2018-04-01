//
//  MailChimp.swift
//  stts
//

import Kanna

class MailChimp: Service {
    let url = URL(string: "https://status.mailchimp.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let messagesURL = URL(string: "https://status.mailchimp.com/messages")!

        URLSession.shared.dataTask(with: messagesURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = try? HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            self?.status = selfie.status(from: doc)
            self?.message = doc.css(".message-status").first?.css("h1").first?.text ?? ""
        }.resume()
    }
}

extension MailChimp {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        guard let mostRecentMessage = document.css(".message-status").first?.className else { return .undetermined }

        if mostRecentMessage.range(of: "message-status-g") != nil {
            return .good
        } else if mostRecentMessage.range(of: "message-status-r") != nil {
            return .major
        } else if mostRecentMessage.range(of: "message-status-y") != nil {
            return .minor
        } else if mostRecentMessage.range(of: "message-status-k") != nil {
            return .maintenance
        } else {
            return .undetermined
        }
    }
}
