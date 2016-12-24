//
//  GitHub.swift
//  stts
//

import Cocoa

class GitHub: Service {
    override var url: URL { return URL(string: "https://status.github.com")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        let lastMessageURL = URL(string: "https://status.github.com/api/last-message.json")!

        URLSession.shared.dataTask(with: lastMessageURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String : String] else { return selfie._fail("Unexpected data") }

            guard let status = dict["status"] else { return selfie._fail("Unexpected data") }

            switch status {
                case "good": self?.status = .good
                case "minor": self?.status = .minor
                case "major": self?.status = .major
                default: self?.status = .undetermined
            }

            self?.message = dict["body"] ?? ""
        }.resume()
    }
}
