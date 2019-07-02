//
//  AzureDevOpsStore.swift
//  stts
//

import Kanna

protocol AzureDevOpsStoreService {
    var serviceName: String { get }
}

private struct AzureDevOpsDataProviders: Codable {
    struct ResponseData: Codable {
        struct DataProvider: Codable {
            struct DataServiceStatus: Codable {
                struct DataService: Codable {
                    struct DataGeography: Codable {
                        let name: String
                        let health: Int

                        var status: ServiceStatus {
                            switch health {
                            case 1: return .major
                            case 2: return .minor
                            case 3: return .notice
                            case 4: return .good
                            default: return .undetermined
                            }
                        }
                    }

                    let id: String
                    let geographies: [DataGeography]

                    var status: ServiceStatus {
                        return geographies.map { $0.status }.max() ?? .undetermined
                    }
                }

                let services: [DataService]
            }

            let serviceStatus: DataServiceStatus
        }

        enum CodingKeys: String, CodingKey {
            case dataProvider = "ms.vss-status-web.public-status-data-provider"
        }

        let dataProvider: DataProvider
    }

    let data: ResponseData
}

class AzureDevOpsStore: Loading {
    private var url = URL(string: "https://status.dev.azure.com")!
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

            guard
                let doc = try? HTML(html: data, encoding: .utf8),
                let json = doc.css("script#dataProviders").first?.innerHTML,
                let jsonData = json.data(using: .utf8),
                let providers = try? JSONDecoder().decode(AzureDevOpsDataProviders.self, from: jsonData)
            else {
                return self._fail("Couldn't parse response")
            }

            providers.data.dataProvider.serviceStatus.services.forEach {
                self.statuses[$0.id] = $0.status
            }

            self.lastUpdateTime = Date.timeIntervalSinceReferenceDate
        }
    }

    func status(for service: AzureDevOpsStoreService) -> (ServiceStatus, String) {
        let status = statuses[service.serviceName]

        switch status {
        case .good?: return (.good, "Healthy")
        case .minor?: return (.minor, "Degraded")
        case .major?: return (.major, "Unhealthy")
        case .notice?: return (.notice, "Advisory")
        default: return (.undetermined, loadErrorMessage ?? "Unexpected error")
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
