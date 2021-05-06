//
//  AdobeStore.swift
//  stts
//

import Foundation

protocol AdobeStoreService {
    var id: Int { get }
}

private struct JSONStructure: Codable {
    struct Product: Codable {
        struct Service: Codable {
            let id: Int
        }

        struct Event: Codable {
            // 1=major, 2=minor, 4=maintenance, 5=potential-issue
            let eventType: Int

            // Don't know what this means besides > 3 meaning it shouldn't count
            let eventState: Int

            // 1=opened, 2=started, 3=updated, 4=closed, 5=cancelled, 6=completed, 7=reopened, 8=updated, 9=scheduled
            // let eventStatus: Int

            var status: ServiceStatus {
                switch eventType {
                case 1: return .major
                case 2: return .minor
                case 4: return .maintenance
                case 5: return .notice // "Potential issue"
                default: return .undetermined
                }
            }
        }

        let service: Service
        let cloud: Int?
        let ongoing: [Event]?

        var status: ServiceStatus {
            let currentEvents = ongoing?.filter({ $0.eventState <= 3 })
            return currentEvents?.map { $0.status }.max() ?? .good
        }
    }

    struct Localization: Codable {
        struct English: Codable {
            let localizeValues: [String: String]
        }

        let en: English
    }

    let products: [Product]
    let localizationValues: Localization
}

class AdobeStore: Loading {
    private var url = URL(string: "https://data.status.adobe.com/adobestatus/currentstatus")!
    private var statuses: [Int: ServiceStatus] = [:]
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

            guard let structure = try? JSONDecoder().decode(JSONStructure.self, from: data) else {
                return self._fail("Unexpected data")
            }

            var cloudStatuses = [Int: [ServiceStatus]]()

            structure.products.forEach {
                // Add the status of that particular service
                self.statuses[$0.service.id] = $0.status

                guard let cloud = $0.cloud else { return }

                // Add the status of that service to the category, so that we can deduce a status for it
                var thisCloudStatuses = cloudStatuses[cloud] ?? []
                thisCloudStatuses.append($0.status)
                cloudStatuses[cloud] = thisCloudStatuses
            }

            cloudStatuses.forEach { cloudID, statuses in
                guard let maxStatus = statuses.max() else { return }
                self.statuses[cloudID] = maxStatus
            }

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: AdobeStoreService) -> (ServiceStatus, String) {
        let status = statuses[service.id]

        switch status {
        case .good?: return (.good, "Available")
        case .minor?: return (.minor, "Minor issue(s)")
        case .major?: return (.major, "Major issue(s)")
        case .notice?: return (.notice, "Potential issue(s)")
        case .maintenance?: return (.maintenance, "Maintenance")
        case .some(.undetermined),
             .none: return (.undetermined, loadErrorMessage ?? "Unexpected error")
        }
    }

    private func clearCallbacks() {
        callbacks.forEach { $0() }
        callbacks = []
    }

    private func _fail(_ error: Error?) {
        _fail(ServiceStatusMessage.from(error))
    }

    private func _fail(_ message: String) {
        loadErrorMessage = message
        lastUpdateTime = 0
    }
}
