//
//  Heroku.swift
//  stts
//

import Foundation

class Heroku: Service {
    override var url: URL { return URL(string: "https://status.heroku.com/")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        let statusURL = URL(string: "https://status.heroku.com/api/v3/current-status")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String : Any] else { return selfie._fail("Unexpected data") }

            guard let status = dict["status"] as? [String : String] else { return selfie._fail("Unexpected data") }

            let devStatus = status["Development"]
            let prodStatus = status["Production"]

            let devGreen = devStatus == "green"
            let prodGreen = prodStatus == "green"

            let statuses = [devStatus, prodStatus].flatMap { $0 }
            if statuses.contains("red") {
                self?.status = .major
            } else if statuses.contains("yellow") {
                self?.status = .minor
            } else if statuses.contains("blue") {
                self?.status = .maintenance
            } else if devGreen && prodGreen {
                self?.status = .good
            } else {
                self?.status = .undetermined
            }

            // Prefer "production" status text except when it's green
            let statusText = (prodGreen ? devStatus : prodStatus)?.capitalized

            // Get the title of the current issue if any
            var title: String?
            if !prodGreen || !devGreen {
                if let issues = dict["issues"] as? [[String : Any]] {
                    title = issues.first?["title"] as? String
                }
            }

            self?.message = title ?? statusText ?? ""
        }.resume()
    }
}
