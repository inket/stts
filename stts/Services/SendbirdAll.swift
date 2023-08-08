//
//  SendbirdAll.swift
//  SendbirdAll
//

import Foundation

class SendbirdAll: IndependentService, ServiceCategory {
    let categoryName = "Sendbird"
    let subServiceSuperclass: AnyObject.Type = SendbirdService.self

    let name = "Sendbird (All)"
    let url = URL(string: "https://sendbird.com/status")!

    lazy var sendbirdServiceDefinitions: [SendbirdServiceDefinition] = {
        ServiceLoader.current.allServices.compactMap { $0 as? SendbirdServiceDefinition }
    }()

    lazy var sendbirdServices: [SendbirdService] = {
        sendbirdServiceDefinitions.compactMap { $0.build() as? SendbirdService }
    }()

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let group = DispatchGroup()

        sendbirdServices.forEach { service in
            group.enter()

            service.updateStatus { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }

            let worstStatus = sendbirdServices.map { $0.status }.max() ?? .undetermined
            let message: String

            switch worstStatus {
            case .undetermined: message = "Unexpected response"
            case .good: message = "Operational"
            case .minor: message = "Minor outage"
            case .major: message = "Major outage"
            case .notice: message = "Degraded service"
            case .maintenance: message = "Maintenance"
            }

            statusDescription = ServiceStatusDescription(status: worstStatus, message: message)
            callback(self)
        }
    }
}
