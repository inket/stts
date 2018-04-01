//
//  GoogleCloudPlatformStatusStore.swift
//  stts
//

import Kanna

struct GoogleCloudPlatformStatusStore {
    private static var statuses: [String: ServiceStatus] = [:]
    private static var loadErrorMessage: String?
    private static var callbacks: [() -> Void] = []
    private static var lastUpdateTime: TimeInterval = 0
    private static var currentlyReloading: Bool = false

    static func loadStatus(for service: BaseGoogleCloudPlatform, callback: @escaping () -> Void) {
        callbacks.append(callback)

        guard !currentlyReloading else { return }
        guard Date.timeIntervalSinceReferenceDate - lastUpdateTime >= 60 else { return clearCallbacks() }

        self.currentlyReloading = true

        URLSession.shared.dataTask(with: URL(string: "https://status.cloud.google.com")!) { data, _, error in
            self.statuses = [:]

            guard let data = data else { return _fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return _fail("Unreadable response") }
            guard let doc = try? HTML(html: body, encoding: .utf8) else { return _fail("Couldn't parse response") }

            for tr in doc.css(".timeline tr") {
                guard let (name, status) = parseTimelineRow(tr) else { continue }
                statuses[name] = status
            }

            clearCallbacks()

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
            self.currentlyReloading = false
        }.resume()
    }

    static func status(for service: GoogleCloudPlatform) -> (ServiceStatus, String) {
        guard let status = statuses[service.name] else { return (.undetermined, loadErrorMessage ?? "Unexpected error") }

        switch status {
        case .good: return (status, "Normal Operations")
        case .minor: return (status, "Service Disruption")
        case .major: return (status, "Service Outage")
        default: return (status, "Unexpected error")
        }
    }

    private static func clearCallbacks() {
        updateGeneralStatus()

        callbacks.forEach { $0() }
        self.callbacks = []
    }

    private static func updateGeneralStatus() {
        let generalStatus: ServiceStatus

        let badServices = statuses.values.filter { ($0 != .good) && ($0 != .undetermined) }
        if badServices.count > 2 {
            generalStatus = .major
        } else if badServices.count > 0 {
            generalStatus = .minor
        } else {
            generalStatus = .good
        }

        statuses["Google Cloud Platform (All)"] = generalStatus
    }

    private static func parseTimelineRow(_ tr: XMLElement) -> (String, ServiceStatus)? {
        guard let name = tr.css(".service-status").first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }

        if tr.css(".end-bubble.ok").count > 0 {
            return (name, .good)
        } else if tr.css(".end-bubble.medium").count > 0 {
            return (name, .minor)
        } else if tr.css(".end-bubble.high").count > 0 {
            return (name, .major)
        } else {
            return (name, .undetermined)
        }
    }

    private static func _fail(_ error: Error?) {
        self.loadErrorMessage = error?.localizedDescription ?? "Unexpected error"
    }

    private static func _fail(_ message: String) {
        self.loadErrorMessage = message
    }
}
