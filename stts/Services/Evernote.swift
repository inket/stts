//
//  Evernote.swift
//  stts
//

import Foundation
import Kanna

class Evernote: Service {
    let url = URL(string: "https://status.evernote.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            strongSelf.statusDescription = strongSelf.status(from: doc)
        }
    }
}

extension Evernote {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatusDescription {
        guard let mostRecentPost = document.css(".post h3").first?.text else {
            return ServiceStatusDescription(status: .undetermined, message: "Unexpected response")
        }

        if mostRecentPost.hasPrefix("[ok]") {
            return ServiceStatusDescription(status: .good, message: mostRecentPost)
        } else if mostRecentPost.hasPrefix("[!]") {
            return ServiceStatusDescription(status: .major, message: mostRecentPost)
        } else {
            return ServiceStatusDescription(status: .maintenance, message: mostRecentPost)
        }
    }
}
