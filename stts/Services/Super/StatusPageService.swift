//
//  StatusPageService.swift
//  stts
//

import Foundation

struct StatusPageServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case id
        case oldName = "old_name"
        case host
    }

    let name: String
    let url: URL
    let id: String
    let oldName: String?
    let host: String?

    var legacyIdentifier: String { oldName ?? name }
    var globalIdentifier: String { "statuspage.\(id)" }

    func build() -> BaseService? {
        StatusPageService(self)
    }
}

class StatusPageService: Service {
    let id: String
    let name: String
    let url: URL
    let oldName: String?
    let host: String

    init(_ definition: StatusPageServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
        oldName = definition.oldName
        host = definition.host ?? "statuspage.io"
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let summaryURL = URL(string: "https://\(id).\(host)/api/v2/summary.json")!

        debugPrint("[StatusPage] Updating status for \(name)…")

        let retainedName = name

        loadData(with: summaryURL) { [weak self] data, _, error in

            guard let strongSelf = self else {
                debugPrint("[StatusPage] \(retainedName) released before callback")
                return
            }

            defer { callback(strongSelf) }

            guard let data = data else {
                debugPrint("[StatusPage] Response for \(retainedName) is nil")
                return strongSelf._fail(error)
            }

            guard let summary = try? JSONDecoder().decode(Summary.self, from: data) else {
                debugPrint("[StatusPage] Could not decode response for \(strongSelf.name)")
                return strongSelf._fail("Unexpected data")
            }

            debugPrint("[StatusPage] Got response for \(retainedName)")

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
            let affectedComponents = summary.sortedComponents.filter { $0.status != .operational }
            if !affectedComponents.isEmpty {
                let prefix = affectedComponents.count > 1 ? "* " : ""

                self?.message = affectedComponents
                    .map { "\(prefix)\($0.name)" }
                    .joined(separator: "\n")
                return
            }

            // Fallback to the status description
            self?.message = summary.status.description
        }
    }
}

private struct Summary: Codable {
    let components: [Component]
    let incidents: [Incident]
    let status: Status

    var sortedComponents: [Component] {
        var rootPositions = [String: Int]()
        components.forEach {
            if $0.groupID == nil { // root element
                rootPositions[$0.id] = $0.position
            }
        }

        let rootPositionForComponent: (_ component: Component) -> Int = {
            if let groupID = $0.groupID {
                return rootPositions[groupID] ?? 0
            } else {
                return rootPositions[$0.id] ?? 0
            }
        }

        return components.sorted { (a: Component, b: Component) in
            let aSortingID = a.sortingID(withRootPosition: rootPositionForComponent(a))
            let bSortingID = b.sortingID(withRootPosition: rootPositionForComponent(b))
            return aSortingID.localizedCaseInsensitiveCompare(bSortingID) == .orderedAscending
        }
    }
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
    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case isGroup = "group"
        case position
        case name
        case status
    }

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
    }

    let id: String
    let isGroup: Bool
    let groupID: String?
    let position: Int

    let name: String
    let status: ComponentStatus

    func sortingID(withRootPosition rootPosition: Int) -> String {
        [
            String(rootPosition),
            groupID ?? id,
            isGroup ? "0" : String(position),
            name
        ].joined(separator: "_")
    }
}
