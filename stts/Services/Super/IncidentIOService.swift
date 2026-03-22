//
//  IncidentIOService.swift
//  stts
//

import Foundation
import Kanna

class IncidentIOServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "incidentio"

    func build() -> BaseService? {
        IncidentIOService(self)
    }
}

class IncidentIOService: Service {
    let name: String
    let url: URL

    init(_ definition: IncidentIOServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    private func serviceStatus(fromIconSuffix suffix: String) -> ServiceStatus {
        switch suffix {
        case "operational": return .good
        case "degraded-performance", "partial-outage": return .minor
        case "full-outage": return .major
        case "under-maintenance": return .maintenance
        default: return .undetermined
        }
    }

    private func iconSuffix(fromClassName className: String) -> String? {
        guard let range = className.range(of: "text-icon-") else { return nil }
        return String(className[range.upperBound...]).components(separatedBy: " ").first
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        guard let headsUp = doc.css("[data-testid='heads-up']").first else {
            statusDescription = ServiceStatusDescription(status: .good, message: "")
            return
        }

        guard let firstLi = headsUp.css("li").first else {
            throw StatusUpdateError.parseError(nil)
        }

        let statusText = firstLi.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let liSvgClass = firstLi.css("svg").first?.className ?? ""
        let liIconSuffix = iconSuffix(fromClassName: liSvgClass)

        var incidentTitles: [String] = []
        var incidentStatuses: [ServiceStatus] = []

        for anchor in headsUp.css("a") {
            guard let href = anchor["href"], href.hasPrefix("/incidents/") else { continue }

            let title = anchor.css(".items-center").first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let svgClass = anchor.css("svg").first?.className ?? ""

            if let suffix = iconSuffix(fromClassName: svgClass) {
                incidentStatuses.append(serviceStatus(fromIconSuffix: suffix))
            }

            if !title.isEmpty {
                incidentTitles.append(title)
            }
        }

        let overallStatus: ServiceStatus
        if let suffix = liIconSuffix {
            overallStatus = serviceStatus(fromIconSuffix: suffix)
        } else {
            overallStatus = incidentStatuses.max() ?? .undetermined
        }

        let message: String
        if incidentTitles.isEmpty {
            message = statusText
        } else {
            let lines = incidentTitles.map { "* \($0)" }.joined(separator: "\n")
            message = statusText.isEmpty ? lines : "\(statusText)\n\(lines)"
        }

        statusDescription = ServiceStatusDescription(status: overallStatus, message: message)
    }
}
