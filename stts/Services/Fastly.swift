//
//  Fastly.swift
//  stts
//

import Foundation
import Kanna

class Fastly: Service {
    let url = URL(string: "https://status.fastly.com")!

    private enum Status: String, CaseIterable {
        case normal
        case informational
        case maintenance
        case degraded
        case unavailable

        case investigating
        case identified
        case monitoring

        var serviceStatus: ServiceStatus {
            switch self {
            case .normal:
                return .good
            case .informational:
                return .notice
            case .maintenance:
                return .maintenance
            case .degraded:
                return .minor
            case .unavailable:
                return .major
            case .investigating, .identified, .monitoring:
                // Statuses for incidents, but in case they show up...
                return .notice
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            // The page has a table that displays the statuses, their names and their image URLs. We map URLs to names
            // so that we can identify the status from its URL.
            var statusHeaders: [Status] = []
            doc.css("#widget-000301 table tr th").forEach { element in
                if element["colspan"] == nil,
                   let headerText = element.text?.lowercased(),
                   let status = Status(rawValue: headerText) {
                    statusHeaders.append(status)
                }
            }
            var statusImageURLs: [String] = []
            doc.css("#widget-000301 table tr td img").forEach { element in
                if let statusImageURL = element["src"]?.lowercased() {
                    statusImageURLs.append(statusImageURL)
                }
            }

            guard statusHeaders.count == statusImageURLs.count, statusImageURLs.count != 0 else {
                return strongSelf._fail("Unexpected response")
            }

            var urlToStatusMap: [String: Status] = [:]
            statusImageURLs.enumerated().forEach { index, url in
                urlToStatusMap[url] = statusHeaders[index]
            }

            guard
                let blockQuote = doc.css("blockquote").first,
                let statusImageURL = blockQuote.css("img").first?["src"]?.lowercased(),
                let status = urlToStatusMap[statusImageURL],
                let statusText = blockQuote.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            else {
                return strongSelf._fail("Unexpected response")
            }

            strongSelf.statusDescription = ServiceStatusDescription(status: status.serviceStatus, message: statusText)
        }
    }
}
