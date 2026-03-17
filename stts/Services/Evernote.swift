//
//  Evernote.swift
//  stts
//

import Foundation
import Kanna

class Evernote: IndependentService {
    let url = URL(string: "https://status.evernote.com")!

    override func updateStatus() async throws {
        let doc = try await html(from: url)
        statusDescription = status(from: doc)
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
