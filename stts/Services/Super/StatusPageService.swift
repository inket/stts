//
//  StatusPageService.swift
//  stts
//
//  Created by inket on 19/8/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class StatusPageService: Service {
    var statusPageID: String { return "" }

    override func updateStatus(callback: @escaping (Service) -> ()) {
        let statusURL = URL(string: "https://\(statusPageID).statuspage.io/api/v2/status.json")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, _ in
            guard let selfie = self else { return }
            guard let data = data else { return }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = (json as? [String : Any])?["status"] as? [String : String] else { return }

            guard let status = dict["indicator"] else { return }

            switch status.lowercased() {
                case "none": self?.status = .good
                case "minor": self?.status = .minor
                case "major", "critical": self?.status = .major
                default: self?.status = .undetermined
            }

            self?.message = dict["description"] ?? ""

            callback(selfie)
        }.resume()
    }
}
