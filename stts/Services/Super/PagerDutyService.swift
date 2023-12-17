//
//  PagerDutyService.swift
//  stts
//

import Foundation
import Kanna

typealias PagerDutyService = BasePagerDutyService & RequiredServiceProperties & RequiredPagerDutyProperties

protocol RequiredPagerDutyProperties {}

class BasePagerDutyService: BaseService {
    private struct PagerDutyData: Codable {
        struct Summary: Codable {
            enum CodingKeys: String, CodingKey {
                case openIncidents = "open_incidents"
            }

            struct Incident: Codable {
                struct Update: Codable {
                    enum Severity: String, Codable {
                        case allGood = "all_good"
                        case minor
                        case major
                        case maintenance

                        var serviceStatus: ServiceStatus {
                            switch self {
                            case .allGood:
                                return .good
                            case .minor:
                                return .minor
                            case .major:
                                return .major
                            case .maintenance:
                                return .maintenance
                            }
                        }
                    }

                    let severity: Severity
                }

                let title: String
                let updates: [Update]
            }

            let openIncidents: [Incident]
        }

        let summary: Summary
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? PagerDutyService else {
            fatalError("BasePagerDutyService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard
                let doc = try? HTML(html: data, encoding: .utf8),
                let json = doc.css("script#data").first?.innerHTML,
                let jsonData = json.data(using: .utf8),
                let data = try? JSONDecoder().decode(PagerDutyData.self, from: jsonData)
            else {
                return strongSelf._fail("Couldn't parse response")
            }

            let incidents = data.summary.openIncidents
            switch incidents.count {
            case 0:
                strongSelf.statusDescription = ServiceStatusDescription(status: .good, message: "No known issue")
            case 1:
                strongSelf.statusDescription = ServiceStatusDescription(
                    status: incidents[0].updates.first?.severity.serviceStatus ?? .good,
                    message: incidents[0].title
                )
            default:
                strongSelf.statusDescription = ServiceStatusDescription(
                    status: incidents.map { $0.updates.first?.severity.serviceStatus ?? .good  }.max() ?? .good,
                    message: incidents.map { "- \($0.title)" }.joined(separator: "\n")
                )
            }
        }
    }
}
