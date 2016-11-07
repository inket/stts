//
//  AmazonWebServices.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class AmazonWebServices: Service {
    override var name: String { return "Amazon Web Services" }
    override var url: URL { return URL(string: "https://status.aws.amazon.com")! }

    override func updateStatus(callback: @escaping (Service) -> ()) {
        let dataURL = URL(string: "https://status.aws.amazon.com/data.json")!

        URLSession.shared.dataTask(with: dataURL) { [weak self] data, _, _ in
            guard let selfie = self else { return }
            guard let data = data else { return }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String : Any] else { return }

            guard let currentIssues = dict["current"] as? [Any] else { return }

            if currentIssues.count == 0 {
                self?.status = .good
            } else if currentIssues.count < 3 {
                self?.status = .minor
            } else {
                self?.status = .major
            }

            if let firstIssue = currentIssues.first as? [String : String] {
                self?.message = firstIssue["summary"] ?? "Click for details"
            } else {
                self?.message = "No recent events"
            }

            callback(selfie)
        }.resume()
    }

}
