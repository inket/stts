//
//  AzureStore.swift
//  stts
//

import Kanna

protocol AzureStoreService {
    var name: String { get }
    var zoneIdentifier: String { get }
}

class AzureStore: Loading {
    private var url = URL(string: "https://status.azure.com/en-us/status")!
    private var statuses: [String: ServiceStatus] = [:]
    private var loadErrorMessage: String?
    private var callbacks: [() -> Void] = []
    private var lastUpdateTime: TimeInterval = 0
    private var currentlyReloading: Bool = false

    func loadStatus(_ callback: @escaping () -> Void) {
        callbacks.append(callback)

        guard !currentlyReloading else { return }

        // Throttling to prevent multiple requests if the first one finishes too quickly
        guard Date.timeIntervalSinceReferenceDate - lastUpdateTime >= 3 else { return clearCallbacks() }

        currentlyReloading = true

        loadData(with: url) { data, _, error in
            defer {
                self.currentlyReloading = false
                self.clearCallbacks()
            }

            self.statuses = [:]

            guard let data = data else { return self._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return self._fail("Couldn't parse response") }

            let zones = doc.css("li.zone[role=presentation]").compactMap { $0["data-zone-name"] }
            zones.forEach { identifier in
                let table = doc.css("table.status-table.region-status-table[data-zone-name=\(identifier)]").first

                table.map {
                    guard let status = self.parseZoneTable($0) else { return }
                    self.statuses[identifier] = status
                }
            }

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: AzureStoreService) -> (ServiceStatus, String) {
        let status = statuses[service.zoneIdentifier]

        switch status {
        case .good?: return (.good, "Good")
        case .minor?: return (.minor, "Warning")
        case .major?: return (.major, "Critical")
        case .notice?: return (.notice, "Information")
        default: return (.undetermined, loadErrorMessage ?? "Unexpected error")
        }
    }

    private func clearCallbacks() {
        callbacks.forEach { $0() }
        callbacks = []
    }

    private func parseZoneTable(_ table: XMLElement) -> ServiceStatus? {
        return table.css("use").compactMap { svgElement -> ServiceStatus? in
            guard let svgName = svgElement["xlink:href"] else { return nil }

            switch svgName {
            case "#svg-check": return .good
            case "#svg-health-warning": return .minor
            case "#svg-health-error": return .major
            case "#svg-health-information": return .notice
            default: return nil
            }
        }.max()
    }

    private func _fail(_ error: Error?) {
        _fail(ServiceStatusMessage.from(error))
    }

    private func _fail(_ message: String) {
        loadErrorMessage = message
        lastUpdateTime = 0
    }
}
