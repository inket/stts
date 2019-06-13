//
//  Apple.swift
//  stts
//

import Foundation

class Apple: Service {
    private(set) var name = "Apple" // Needed so that AppleDeveloper can override it
    private(set) var url = URL(string: "https://www.apple.com/support/systemstatus/")!
    private(set) var dataURL = URL(string: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.sharedWithoutCaching.dataTask(with: dataURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard
                let originalData = data,
                let jsonData = String(data: originalData, encoding: .utf8)?.innerJSONString.data(using: .utf8)
            else { return strongSelf._fail(error) }

            guard let responseData = try? JSONDecoder().decode(AppleResponseData.self, from: jsonData) else {
                return strongSelf._fail("Unexpected data")
            }

            let worstEvent = responseData.services.compactMap { $0.worstEvent }.max(by: { e1, e2 in
                e1.serviceStatus < e2.serviceStatus
            })

            strongSelf.message = (worstEvent?.realStatus ?? .available).rawValue
            strongSelf.status = worstEvent?.serviceStatus ?? .good
        }.resume()
    }
}

private struct AppleResponseData: Codable {
    struct Service: Codable {
        let serviceName: String
        let events: [Event]

        var worstEvent: Event? {
            return events.max { e1, e2 in e1.serviceStatus < e2.serviceStatus }
        }
    }

    enum EventStatus: String, Codable {
        case ongoing
        case resolved
        case upcoming
        case completed
    }

    enum EventType: String, Codable {
        case available = "Available"
        case outage = "Outage"
        case issue = "Issue"
        case performance = "Performance"
        case maintenance = "Maintenance"
    }

    struct Event: Codable {
        let statusType: EventType
        let eventStatus: EventStatus

        var realStatus: EventType {
            switch eventStatus {
            case .ongoing:
                return statusType
            case .resolved,
                 .upcoming,
                 .completed:
                return .available
            }
        }

        var serviceStatus: ServiceStatus {
            switch realStatus {
            case .available:
                return .good
            case .outage:
                return .major
            case .issue,
                 .performance:
                return .minor
            case .maintenance:
                return .maintenance
            }
        }
    }

    let services: [Service]
}
