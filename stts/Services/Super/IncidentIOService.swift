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
    private enum IncidentIOStatus: String, CaseIterable {
        // e.exports = {
        //     default: "ContentBox_default__oUSYA",
        //     header: "ContentBox_header__qxuY8",
        //     operational: "ContentBox_operational__vH2cn",
        //     degradedPerformance: "ContentBox_degradedPerformance__MxeFS",
        //     partialOutage: "ContentBox_partialOutage__smHQh",
        //     fullOutage: "ContentBox_fullOutage__plntp",
        //     underMaintenance: "ContentBox_underMaintenance__hXg3P"
        // }

        case operational
        case degradedPerformance
        case partialOutage
        case fullOutage
        case underMaintenance

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .degradedPerformance:
                return .minor
            case .partialOutage:
                return .minor
            case .fullOutage:
                return .major
            case .underMaintenance:
                return .maintenance
            }
        }
    }

    let name: String
    let url: URL

    init(_ definition: IncidentIOServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        var statusNode: Kanna.XMLElement?
        var foundStatus: IncidentIOStatus?
        doc.css(".container").first?.xpath("child::node()").forEach { element in
            guard let className = element.className else { return }

            for incidentIOStatus in IncidentIOStatus.allCases {
                if className.lowercased().contains("ContentBox_\(incidentIOStatus.rawValue)".lowercased()) {
                    statusNode = element
                    foundStatus = incidentIOStatus
                    return
                }
            }
        }

        if let statusNode, let foundStatus {
            let status = foundStatus.serviceStatus
            let message = statusNode.css("li")
                .first?
                .content?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unexpected response"

            statusDescription = ServiceStatusDescription(status: status, message: message)
        } else {
            throw StatusUpdateError.decodingError(nil)
        }
    }
}
