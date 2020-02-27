//
//  Cloudflare.swift
//  stts
//

import Foundation

class Cloudflare: StatusPageService {
    let url = URL(string: "https://www.cloudflarestatus.com")!
    let statusPageID = "yh6f0r4529hb"

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        super.updateStatus { service in
            // Cloudflare has special handling that turns any "minor" into "re-routed" and makes it
            // not affect the overall status of the service.
            // See added javascript on bottom of https://www.cloudflarestatus.com
            if service.status == .minor {
                service.status = .good
                service.message = "All Systems Operational"
            }

            callback(service)
        }
    }
}
