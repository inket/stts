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

class FirebaseStatusDashboardStore: Loading {
    private var dashboardURL: URL
    private var statuses: [String: ServiceStatus] = [:]
    private var loadErrorMessage: String?
    private var callbacks: [() -> Void] = []
    private var lastUpdateTime: TimeInterval = 0
    private var currentlyReloading: Bool = false

    init(url: URL) {
        dashboardURL = url
    }

    func loadStatus(_ callback: @escaping () -> Void) {
        callbacks.append(callback)

        guard !currentlyReloading else { return }

        // Throttling to prevent multiple requests if the first one finishes too quickly
        guard Date.timeIntervalSinceReferenceDate - lastUpdateTime >= 3 else { return clearCallbacks() }

        currentlyReloading = true

        loadData(with: dashboardURL) { data, _, error in
            defer {
                self.currentlyReloading = false
                self.clearCallbacks()
            }

            self.statuses = [:]

            guard let data = data else { return self._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return self._fail("Couldn't parse response") }

            for tr in doc.css(".main-dashboard-table tr") {
                guard let (name, status) = self.parseDashboardRow(tr) else { continue }
                self.statuses[name] = status
            }

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: FirebaseStatusDashboardStoreService) -> (ServiceStatus, String) {
        let status: ServiceStatus?

        if type(of: service) == Firebase.self {
            status = statuses["_general"]
        } else {
            status = statuses[service.dashboardName]
        }

        switch status {
        case .good?: return (.good, "Normal Operations")
        case .minor?: return (.minor, "Service Disruption")
        case .major?: return (.major, "Service Outage")
        default: return (.undetermined, loadErrorMessage ?? "Unexpected error")
        }
    }

    private func clearCallbacks() {
        updateGeneralStatus()

        callbacks.forEach { $0() }
        callbacks = []
    }

    private func updateGeneralStatus() {
        let generalStatus: ServiceStatus

        if statuses.keys.filter({ $0 != "_general" }).isEmpty {
            generalStatus = .undetermined
        } else {
            let badServices = statuses.values.filter { ($0 != .good) && ($0 != .undetermined) }
            if badServices.count > 2 {
                generalStatus = .major
            } else if badServices.count > 0 {
                generalStatus = .minor
            } else {
                generalStatus = .good
            }
        }

        statuses["_general"] = generalStatus
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

    private func _fail(_ error: Error?) {
        _fail(ServiceStatusMessage.from(error))
    }

    private func _fail(_ message: String) {
        loadErrorMessage = message
        lastUpdateTime = 0
    }
}
