//
//  StatusPageService.swift
//  stts
//

import Foundation

typealias StatusPageService = BaseStatusPageService & RequiredServiceProperties & RequiredStatusPageProperties

protocol RequiredStatusPageProperties {
    var statusPageID: String { get }
    var domain: String { get }
}

extension RequiredStatusPageProperties {
    var domain: String {
        return "statuspage.io"
    }
}

class BaseStatusPageService: BaseService {
    private struct Summary: Codable {
        let components: [Component]
        let incidents: [Incident]
        let status: Status
    }

    private struct Status: Codable {
        enum Indicator: String, Codable {
            case none
            case minor
            case critical
            case major
            case maintenance

            var serviceStatus: ServiceStatus {
                switch self {
                case .none:
                    return .good
                case .minor:
                    return .minor
                case .critical,
                     .major:
                    return .major
                case .maintenance:
                    return .maintenance
                }
            }
        }

        let description: String
        let indicator: Indicator
    }

    private struct Incident: Codable {
        enum IncidentStatus: String, Codable {
            case investigating
            case identified
            case monitoring
            case resolved
            case postmortem
        }

        let id: String
        let name: String
        let status: IncidentStatus

        var isUnresolved: Bool {
            switch status {
            case .investigating, .identified, .monitoring:
                return true
            case .resolved, .postmortem:
                return false
            }
        }
    }

    private struct Component: Codable {
        enum ComponentStatus: String, Codable {
            case operational
            case majorOutage = "major_outage"
            case degradedPerformance = "degraded_performance"
            case partialOutage = "partial_outage"
            case underMaintenance = "under_maintenance"

            var serviceStatus: ServiceStatus {
                switch self {
                case .operational:
                    return .good
                case .majorOutage:
                    return .major
                case .degradedPerformance,
                     .partialOutage:
                    return .minor
                case .underMaintenance:
                    return .maintenance
                }
            }

            var statusMessage: String {
                switch self {
                case .operational:
                    return "Operational"
                case .majorOutage:
                    return "Major Outage"
                case .degradedPerformance:
                    return "Degraded Performance"
                case .partialOutage:
                    return "Partial Outage"
                case .underMaintenance:
                    return "Under Maintenance"
                }
            }
        }

        let id: String
        let name: String
        let status: ComponentStatus
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusPageService else {
            fatalError("BaseStatusPageService should not be used directly.")
        }

        let summaryURL = URL(string: "https://\(realSelf.statusPageID).\(realSelf.domain)/api/v2/summary.json")!

        loadData(with: summaryURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }

            guard let summary = try? JSONDecoder().decode(Summary.self, from: data) else {
                return strongSelf._fail("Unexpected data")
            }

            // Set the status
            self?.status = summary.status.indicator.serviceStatus

            // Set the message by combining the unresolved incident names
            let unresolvedIncidents = summary.incidents.filter { $0.isUnresolved }
            if !unresolvedIncidents.isEmpty {
                let prefix = unresolvedIncidents.count > 1 ? "* " : ""
                self?.message = unresolvedIncidents.map { "\(prefix)\($0.name)" }.joined(separator: "\n")
                return
            }

            // Or from affected the component names
            let affectedComponents = summary.components.filter { $0.status != .operational }
            if !affectedComponents.isEmpty {
                let prefix = affectedComponents.count > 1 ? "* " : ""

                self?.message = affectedComponents
                    .map { "\(prefix)\($0.status.statusMessage) with \($0.name)" }
                    .joined(separator: "\n")
                return
            }

            // Fallback to the status description
            self?.message = summary.status.description
        }
    }
}
