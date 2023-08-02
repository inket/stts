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

class GoogleStatusDashboardStore: Loading {
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

            for tr in doc.css("psd-regional-table tbody tr") {
                guard let (name, status) = self.parseDashboardRow(tr) else { continue }
                self.statuses[name] = status
            }

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: GoogleStatusDashboardStoreService) -> ServiceStatusDescription {
        let status: ServiceStatus?

        if type(of: service) == GoogleCloudPlatformAll.self {
            status = statuses["_general"]
        } else {
            status = statuses[service.dashboardName]
        }

        switch status {
        case .good: return ServiceStatusDescription(status: .good, message: "Available")
        case .notice: return ServiceStatusDescription(status: .notice, message: "Service information")
        case .minor: return ServiceStatusDescription(status: .minor, message: "One or more regions affected")
        case .major: return ServiceStatusDescription(status: .major, message: "Service outage")
        default: return ServiceStatusDescription(status: .undetermined, message: loadErrorMessage ?? "Unexpected error")
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

    private func _fail(_ error: Error?) {
        _fail(ServiceStatusMessage.from(error))
    }

    private func _fail(_ message: String) {
        loadErrorMessage = message
        lastUpdateTime = 0
    }
}
