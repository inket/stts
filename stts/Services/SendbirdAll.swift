//
//  SendbirdAll.swift
//  SendbirdAll
//

import Foundation

class SendbirdAll: SendbirdService, ServiceCategory {
    let categoryName = "Sendbird"
    let subServiceSuperclass: AnyObject.Type = BaseSendbirdService.self

    let name = "Sendbird (All)"
    let url = URL(string: "https://sendbird.com/status")!
    let statusPageID = "" // dummy

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let services: [Service] = Sendbird.classes.compactMap { $0.init() as? Service }
        let group = DispatchGroup()

        services.forEach { service in
            group.enter()

            service.updateStatus { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            let worstStatus = services.map { $0.status }.max() ?? .undetermined
            let message: String

            switch worstStatus {
            case .undetermined: message = "Undetermined"
            case .good: message = "Operational"
            case .minor: message = "Minor outage"
            case .major: message = "Major outage"
            case .notice: message = "Degraded service"
            case .maintenance: message = "Maintenance"
            }

            self.status = worstStatus
            self.message = message

            callback(self)
        }
    }
}
