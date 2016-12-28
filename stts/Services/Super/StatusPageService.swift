//
//  StatusPageService.swift
//  stts
//

import Foundation

class StatusPageService: Service {
    var statusPageID: String { return "" }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        let statusURL = URL(string: "https://\(statusPageID).statuspage.io/api/v2/status.json")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = (json as? [String : Any])?["status"] as? [String : String] else {
                return selfie._fail("Unexpected data")
            }

            guard let status = dict["indicator"] else { return selfie._fail("Unexpected data") }

            switch status.lowercased() {
                case "none": self?.status = .good
                case "minor": self?.status = .minor
                case "major", "critical": self?.status = .major
                default: self?.status = .undetermined
            }

            self?.message = dict["description"] ?? ""
        }.resume()
    }
}
