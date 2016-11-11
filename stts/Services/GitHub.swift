//
//  GitHub.swift
//  stts
//
//  Created by inket on 28/7/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class GitHub: Service {
    override var name: String { return "GitHub" }
    override var url: URL { return URL(string: "https://status.github.com")! }

    override func updateStatus(callback: @escaping (Service) -> ()) {
        let lastMessageURL = URL(string: "https://status.github.com/api/last-message.json")!

        URLSession.shared.dataTask(with: lastMessageURL) { [weak self] data, response, error in
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
