//
//  Okta.swift
//  stts
//

import Foundation
import Kanna

class Okta: IndependentService {
    private struct Incident: Decodable {
        let status: String
        let category: String
        let serviceFeature: String?

        enum CodingKeys: String, CodingKey {
            case status = "Status__c"
            case category = "Category__c"
            case serviceFeature = "Service_Feature__c"
        }
    }

    private enum Category: String {
        case serviceDisruption = "Service Disruption"
        case majorServiceDisruption = "Major Service Disruption"
        case minorServiceDisruption = "Minor Service Disruption"
        case serviceDegradation = "Service Degradation"
        case performanceIssue = "Performance Issue"
        case featureDisruption = "Feature Disruption"

        var serviceStatus: ServiceStatus {
            switch self {
            case .serviceDisruption, .majorServiceDisruption, .minorServiceDisruption:
                return .major
            case .serviceDegradation, .performanceIssue, .featureDisruption:
                return .minor
            }
        }
    }

    let url = URL(string: "https://status.okta.com")!

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        guard
            let incidentsSpan = doc.css("[data-id='incidents']").first,
            let jsonText = incidentsSpan.text,
            let jsonData = jsonText.data(using: .utf8)
        else {
            throw StatusUpdateError.parseError(nil)
        }

        let incidents: [Incident]
        do {
            incidents = try JSONDecoder().decode([Incident].self, from: jsonData)
        } catch {
            throw StatusUpdateError.decodingError(error)
        }

        let openIncidents = incidents.filter { $0.status != "Resolved" }

        if openIncidents.isEmpty {
            statusDescription = ServiceStatusDescription(status: .good, message: "System Operational")
            return
        }

        let worstStatus = openIncidents.compactMap { incident -> ServiceStatus? in
            if incident.serviceFeature == "tp" {
                return .minor
            }
            return Category(rawValue: incident.category)?.serviceStatus
        }.max() ?? .undetermined

        let categories = Set(openIncidents.map { $0.category })
        let message = categories.sorted().joined(separator: ", ")

        statusDescription = ServiceStatusDescription(status: worstStatus, message: message)
    }
}
