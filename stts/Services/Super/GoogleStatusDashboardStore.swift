//
//  GoogleStatusDashboardStore.swift
//  stts
//

import Foundation
import Kanna

protocol GoogleStatusDashboardStoreService {
    var name: String { get }
    var dashboardName: String { get }
}

extension GoogleStatusDashboardStoreService {
    var dashboardName: String {
        return name
    }
}

class GoogleStatusDashboardStore: ServiceStore<[String: ServiceStatus]> {
    private let dashboardURL: URL

    init(url: URL) {
        dashboardURL = url
    }

    override func retrieveUpdatedState() async throws -> [String: ServiceStatus] {
        let doc = try await html(from: dashboardURL)

        var statuses: [String: ServiceStatus] = [:]
        var badStatuses: [ServiceStatus] = []

        for tr in doc.css("psd-regional-table tbody tr") {
            guard let (name, status) = self.parseDashboardRow(tr) else { continue }
            statuses[name] = status

            if status != .good && status != .undetermined {
                badStatuses.append(status)
            }
        }

        let generalStatus: ServiceStatus
        if badStatuses.count > 2 {
            generalStatus = .major
        } else if badStatuses.count > 0 {
            generalStatus = .minor
        } else {
            generalStatus = .good
        }
        statuses["_general"] = generalStatus

        return statuses
    }

    func updatedStatus(for service: GoogleStatusDashboardStoreService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        let status: ServiceStatus?

        if type(of: service) == GoogleCloudPlatformAll.self {
            status = updatedState["_general"]
        } else {
            status = updatedState[service.dashboardName]
        }

        switch status {
        case .good: return ServiceStatusDescription(status: .good, message: "Available")
        case .notice: return ServiceStatusDescription(status: .notice, message: "Service information")
        case .minor: return ServiceStatusDescription(status: .minor, message: "One or more regions affected")
        case .major: return ServiceStatusDescription(status: .major, message: "Service outage")
        default: return ServiceStatusDescription(status: .undetermined, message: loadErrorMessage ?? "Unexpected error")
        }
    }

    private func parseDashboardRow(_ tr: Kanna.XMLElement) -> (String, ServiceStatus)? {
        let rawName = tr.css("th").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedName = rawName?
            .components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let name = sanitizedName else { return nil }

        let iconClassNames = tr.css("psd-status-icon svg").compactMap { $0.className }
        guard !iconClassNames.isEmpty else {
            // Unexpected
            return nil
        }

        let statuses: [ServiceStatus] = iconClassNames.map {
            if $0.contains("__available") {
                return .good
            } else if $0.contains("__information") {
                return .notice
            } else if $0.contains("__warning") || $0.contains("__disruption") {
                return .minor
            } else if $0.contains("__outage") {
                return .major
            } else {
                return .undetermined
            }
        }

        let max = statuses.max() ?? .undetermined
        return (name, max)
    }
}
