//
//  AzureDevOpsStore.swift
//  stts
//

import Foundation
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

class AzureDevOpsStore: ServiceStore<[String: ServiceStatus]> {
    private let url = URL(string: "https://status.dev.azure.com")!

    override func retrieveUpdatedState() async throws -> [String: ServiceStatus] {
        let doc = try await html(from: url)

        guard
            let json = doc.css("script#dataProviders").first?.innerHTML,
            let jsonData = json.data(using: .utf8)
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let providers: AzureDevOpsDataProviders
        do {
            providers = try JSONDecoder().decode(AzureDevOpsDataProviders.self, from: jsonData)
        } catch {
            throw StatusUpdateError.decodingError(error)
        }

        var statuses: [String: ServiceStatus] = [:]
        providers.data.dataProvider.serviceStatus.services.forEach {
            statuses[$0.id] = $0.status
        }

        return statuses
    }

    func updatedStatus(for service: AzureDevOpsStoreService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        let status: ServiceStatus?

        if service.serviceName == "*" {
            status = updatedState.values.max()
        } else {
            status = updatedState[service.serviceName]
        }

        switch status {
        case .good?: return ServiceStatusDescription(status: .good, message: "Healthy")
        case .minor?: return ServiceStatusDescription(status: .minor, message: "Degraded")
        case .major?: return ServiceStatusDescription(status: .major, message: "Unhealthy")
        case .notice?: return ServiceStatusDescription(status: .notice, message: "Advisory")
        default: return ServiceStatusDescription(status: .undetermined, message: loadErrorMessage ?? "Unexpected error")
        }
    }
}
