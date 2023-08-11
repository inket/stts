//
//  Beanstalk.swift
//  stts
//

import Foundation
import Kanna

class Beanstalk: IndependentService {
    let url = URL(string: "https://status.beanstalkapp.com")!

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        let status = status(from: doc)
        statusDescription = ServiceStatusDescription(
            status: status,
            message: message(for: status)
        )
    }
}

extension Beanstalk {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        let firstStatus = document.css("#updates article:first .status").compactMap { $0.text }.first

        guard let status = firstStatus else { return .undetermined }

        switch status {
        case "ok", "pending": return .good
        case "maintenance": return .maintenance
        case "problem": return .major
        default: return .undetermined
        }
    }

    fileprivate func message(for status: ServiceStatus) -> String {
        switch status {
        case .good: return "Services operating normally."
        case .major: return "Experiencing service interruptions."
        case .maintenance: return "Scheduled maintenance in progress."
        default: return "Unexpected response"
        }
    }
}
