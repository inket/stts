//
//  AzureStore.swift
//  stts
//

import Foundation
import Kanna

protocol AzureStoreService {
    var name: String { get }
    var zoneIdentifier: String { get }
}

class AzureStore: ServiceStore<[String: ServiceStatus]> {
    private let url = URL(string: "https://status.azure.com/en-us/status")!

    override func retrieveUpdatedState() async throws -> [String: ServiceStatus] {
        let doc = try await html(from: url)

        var statuses: [String: ServiceStatus] = [:]

        let zones = doc.css("li.zone[role=presentation]").compactMap { $0["data-zone-name"] }
        zones.forEach { identifier in
            let table = doc.css("table.status-table.region-status-table[data-zone-name=\(identifier)]").first

            table.map {
                guard let status = self.parseZoneTable($0) else { return }
                statuses[identifier] = status
            }
        }

        return statuses
    }

    func updatedStatus(for service: AzureStoreService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        let status: ServiceStatus?

        if service.zoneIdentifier == "*" {
            status = updatedState.values.max()
        } else {
            status = updatedState[service.zoneIdentifier]
        }

        switch status {
        case .good?: return ServiceStatusDescription(status: .good, message: "Good")
        case .minor?: return ServiceStatusDescription(status: .minor, message: "Warning")
        case .major?: return ServiceStatusDescription(status: .major, message: "Critical")
        case .notice?: return ServiceStatusDescription(status: .notice, message: "Information")
        default: return ServiceStatusDescription(status: .undetermined, message: loadErrorMessage ?? "Unexpected error")
        }
    }

    private func parseZoneTable(_ table: Kanna.XMLElement) -> ServiceStatus? {
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
}
