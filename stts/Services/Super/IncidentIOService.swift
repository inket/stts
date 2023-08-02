//
//  IncidentIOService.swift
//  stts
//

import Foundation
import Kanna

typealias IncidentIOService = BaseIncidentIOService & RequiredServiceProperties & RequiredIncidentIOProperties

protocol RequiredIncidentIOProperties {}

class BaseIncidentIOService: BaseService {
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
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? IncidentIOService else {
            fatalError("BaseIncidentIOService should not be used directly")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let self else { return }
            defer { callback(self) }

            guard let data else { return self._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return self._fail("Couldn't parse response")
            }

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

                self.statusDescription = ServiceStatusDescription(status: status, message: message)
            } else {
                self._fail("Unexpected response")
            }
        }
    }
}
