//
//  SendbirdAll.swift
//  SendbirdAll
//

import Foundation

class SendbirdAll: IndependentService, ServiceCategory {
    static var sendbirdServices: [SendbirdService] = []

    let categoryName = "Sendbird"
    let subServiceSuperclass: AnyObject.Type = SendbirdService.self

    let name = "Sendbird (All)"
    let url = URL(string: "https://sendbird.com/status")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let group = DispatchGroup()

        Self.sendbirdServices.forEach { service in
            group.enter()

            service.updateStatus { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }

            var messageComponents: [String] = []
            for service in Self.sendbirdServices {
                if service.status != .good {
                    messageComponents.append(service.name)
                    messageComponents.append("* \(service.message)")
                }
            }

            let worstStatus = Self.sendbirdServices.map { $0.status }.max() ?? .undetermined
            var message = messageComponents.joined(separator: "\n")

            if message.isEmpty {
                switch worstStatus {
                case .undetermined: message = "Unexpected response"
                case .good: message = "Operational"
                case .minor: message = "Minor outage"
                case .major: message = "Major outage"
                case .notice: message = "Degraded service"
                case .maintenance: message = "Maintenance"
                }
            }

            statusDescription = ServiceStatusDescription(status: worstStatus, message: message)
            callback(self)
        }
    }
}
