//
//  Stripe.swift
//  stts
//

import Kanna

class Stripe: Service {
    let url = URL(string: "https://status.stripe.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }

            guard let bubbleClassName = doc.css(".status-bubble").first?.className else { return strongSelf._fail("Unexpected response") }

            self?.status = strongSelf.status(fromClassName: bubbleClassName)
            self?.message = doc.css(".title-wrapper .title").first?.text ?? "Undetermined"
        }.resume()
    }

    private func status(fromClassName className: String) -> ServiceStatus {
        if className.contains("status-up") {
            return .good
        } else if className.contains("status-down") {
            return .major
        } else if className.contains("status-paused") || className.contains("status-loading") {
            return .maintenance
        } else {
            return .undetermined
        }
    }
}
