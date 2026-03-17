//
//  Fastly.swift
//  stts

import Foundation
import Kanna

class Fastly: IndependentService {
    let url = URL(string: "https://www.fastlystatus.com")!

    private enum Status: String, CaseIterable {
        case available
        case informational
        case maintenance
        case degraded
        case unavailable

        case investigating
        case identified
        case monitoring

        var serviceStatus: ServiceStatus {
            switch self {
            case .available:
                return .good
            case .informational, .identified, .monitoring:
                return .notice
            case .maintenance:
                return .maintenance
            case .degraded, .investigating:
                return .minor
            case .unavailable:
                return .major
            }
        }

        var displayText: String {
            switch self {
            case .available: return "Normal"
            case .informational: return "Informational"
            case .maintenance: return "Maintenance"
            case .degraded: return "Degraded"
            case .unavailable: return "Unavailable"
            case .investigating: return "Investigating"
            case .identified: return "Identified"
            case .monitoring: return "Monitoring"
            }
        }
    }

    // Geographic region names used in the Platform tab — replaced with their parent tab name in messages.
    private static let geographicRegionNames: Set<String> = [
        "North America", "Latin America", "Europe", "Asia", "South America", "Oceania", "Africa"
    ]

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        // Parse tab navigation to build a pid → tab name map.
        // Tab hrefs end with the component group ID, e.g. "#tab-<hash>-510166".
        var tabNames: [String: String] = [:]
        doc.css("a[data-toggle='tab']").forEach { link in
            guard
                let href = link["href"],
                let tabID = href.components(separatedBy: "-").last,
                let text = link.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return }
            tabNames[tabID] = text
        }

        // The page shows a history grid where top-level rows have a simple data-path (no dashes)
        // and the first data column (index 2) shows the current day's status.
        var componentStatuses: [(name: String, status: Status)] = []

        doc.css("tr[data-path]").forEach { row in
            guard let path = row["data-path"], !path.contains("-") else { return }

            let tds = Array(row.css("td"))
            guard tds.count > 2 else { return }

            let currentTd = tds[2]
            guard let icon = currentTd.css("i").first, let className = icon.className else { return }

            for status in Status.allCases where className.contains("component-\(status.rawValue)") {
                let componentName = tds[0].css("a").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // Geographic region names (e.g. "North America") are replaced with their parent tab name (e.g. "Platform")
                let pid = row["data-pid"] ?? ""
                let isRegion = Self.geographicRegionNames.contains(componentName)
                let name = isRegion ? (tabNames[pid] ?? componentName) : componentName
                componentStatuses.append((name: name, status: status))
                break
            }
        }

        guard !componentStatuses.isEmpty else {
            throw StatusUpdateError.decodingError(nil)
        }

        let worstStatus = componentStatuses.max(by: { $0.status.serviceStatus < $1.status.serviceStatus })!.status
        let affected = componentStatuses
            .filter { $0.status != .available }
            .map { $0.name }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        let uniqueAffected = affected.filter { seen.insert($0).inserted }

        let message = uniqueAffected.isEmpty ? worstStatus.displayText : uniqueAffected.joined(separator: ", ")
        statusDescription = ServiceStatusDescription(status: worstStatus.serviceStatus, message: message)
    }
}
