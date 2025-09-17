//
//  PagerDutyService.swift
//  stts
//

import Foundation
import Kanna

typealias PagerDutyService = BasePagerDutyService & RequiredServiceProperties & RequiredPagerDutyProperties

protocol RequiredPagerDutyProperties {}

class BasePagerDutyService: BaseService {
    private struct PagerDutyDataV1: Codable {
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

    private struct PagerDutyDataV2: Codable {
        struct Layout: Codable {
            struct LayoutSettings: Codable {
                struct StatusPage: Codable {
                    let globalStatusHeadline: String
                    let globalStatusHeadlineHasError: Bool
                    let linkText: String
                    let linkUrlText: String
                }

                let statusPage: StatusPage
            }

            let layoutSettings: LayoutSettings

            enum CodingKeys: String, CodingKey {
                case layoutSettings = "layout_settings"
            }
        }

        let layout: Layout

        enum CodingKeys: String, CodingKey {
            case layout
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? PagerDutyService else {
            fatalError("BasePagerDutyService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let self else { return }
            defer { callback(self) }
            guard let data = data else { return _fail(error) }

            guard
                let doc = try? HTML(html: data, encoding: .utf8),
                let json = doc.css("script#data").first?.innerHTML,
                let jsonData = json.data(using: .utf8)
            else {
                return _fail("Couldn't parse response")
            }

            if let data = try? JSONDecoder().decode(PagerDutyDataV1.self, from: jsonData) {
                updateStatus(from: data)
            } else if let data = try? JSONDecoder().decode(PagerDutyDataV2.self, from: jsonData) {
                updateStatus(from: data)
            } else {
                _fail("Couldn't parse response")
            }
        }
    }

    private func updateStatus(from data: PagerDutyDataV1) {
        let incidents = data.summary.openIncidents
        switch incidents.count {
        case 0:
            statusDescription = ServiceStatusDescription(status: .good, message: "No known issue")
        case 1:
            statusDescription = ServiceStatusDescription(
                status: incidents[0].updates.first?.severity.serviceStatus ?? .good,
                message: incidents[0].title
            )
        default:
            statusDescription = ServiceStatusDescription(
                status: incidents.map { $0.updates.first?.severity.serviceStatus ?? .good  }.max() ?? .good,
                message: incidents.map { "- \($0.title)" }.joined(separator: "\n")
            )
        }
    }

    private func updateStatus(from data: PagerDutyDataV2) {
        let status: ServiceStatus = data.layout.layoutSettings.statusPage.globalStatusHeadlineHasError ? .minor : .good
        statusDescription = ServiceStatusDescription(
            status: status,
            message: data.layout.layoutSettings.statusPage.globalStatusHeadline
        )
    }
}
