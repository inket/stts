//
//  Stripe.swift
//  stts
//

import Foundation

private struct StripeCurrentStatus: Codable {
    enum Status: String, Codable {
        case up
        case degraded
        case down

        // Not sure what pending & paused are (maybe temporary states until all data is loaded?), but
        // we'll add them to the enum just in case, and we'll treat them as maintenance like the old version.
        case pending
        case paused

        var serviceStatus: ServiceStatus {
            switch self {
            case .up: return .good
            case .degraded: return .minor
            case .pending, .paused: return .maintenance
            case .down: return .major
            }
        }
    }

    let message: String
    let overallStatus: Status
}

class Stripe: Service {
    let url = URL(string: "https://status.stripe.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url.appendingPathComponent("current/full")) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let currentStatus = try? JSONDecoder().decode(StripeCurrentStatus.self, from: data) else {
                return strongSelf._fail("Couldn't parse response")
            }

            self?.status = currentStatus.overallStatus.serviceStatus
            self?.message = currentStatus.message
        }
    }
}
