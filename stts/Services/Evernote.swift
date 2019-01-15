//
//  Evernote.swift
//  stts
//

import Kanna

class Evernote: Service {
    let url = URL(string: "http://status.evernote.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }

            let (status, message) = strongSelf.status(from: doc)
            self?.status = status
            self?.message = message
        }.resume()
    }
}

extension Evernote {
    fileprivate func status(from document: HTMLDocument) -> (ServiceStatus, String) {
        guard let mostRecentPost = document.css(".post h3").first?.text else { return (.undetermined, "") }

        if mostRecentPost.hasPrefix("[ok]") {
            return (.good, mostRecentPost)
        } else if mostRecentPost.hasPrefix("[!]") {
            return (.major, mostRecentPost)
        } else {
            return (.maintenance, mostRecentPost)
        }
    }
}
