//
//  FirebaseStatusDashboardStore.swift
//  stts
//

import Foundation
import Kanna

protocol FirebaseStatusDashboardStoreService {
    var name: String { get }
    var dashboardName: String { get }
}

extension FirebaseStatusDashboardStoreService {
    var dashboardName: String {
        return name
    }
}

class FirebaseStatusDashboardStore: ServiceStore<[String: ServiceStatus]> {
    private var dashboardURL: URL

    init(url: URL) {
        dashboardURL = url
    }

    override func retrieveUpdatedState() async throws -> [String: ServiceStatus] {
        let doc = try await html(from: dashboardURL)

        var statuses: [String: ServiceStatus] = [:]
        var badStatuses: [ServiceStatus] = []

        for tr in doc.css(".main-dashboard-table tr") {
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

    func updatedStatus(for service: FirebaseStatusDashboardStoreService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        let status: ServiceStatus?

        if type(of: service) == Firebase.self {
            status = updatedState["_general"]
        } else {
            let expandedDashboardName = "Firebase \(service.dashboardName)"
            status = updatedState[service.dashboardName] ?? updatedState[expandedDashboardName]
        }

        switch status {
        case .good?: return ServiceStatusDescription(status: .good, message: "Normal Operations")
        case .minor?: return ServiceStatusDescription(status: .minor, message: "Service Disruption")
        case .major?: return ServiceStatusDescription(status: .major, message: "Service Outage")
        default: return ServiceStatusDescription(status: .undetermined, message: loadErrorMessage ?? "Unexpected error")
        }
    }

    private func parseDashboardRow(_ tr: Kanna.XMLElement) -> (String, ServiceStatus)? {
        let rawName = tr.css(".product-name").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedName = rawName?
            .components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let name = sanitizedName else { return nil }

        if tr.css("svg.psd__status-icon.psd__available").count > 0 {
            return (name, .good)
        } else if tr.css("svg.psd__status-icon.psd__disruption").count > 0 {
            return (name, .minor)
        } else if tr.css("svg.psd__status-icon.psd__outage").count > 0 {
            return (name, .major)
        } else if tr.css("svg.psd__status-icon.psd__information").count > 0 {
            return (name, .notice)
        } else {
            return (name, .undetermined)
        }
    }
}
