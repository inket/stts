//
//  PayPal.swift
//  stts
//

import Foundation

typealias PayPal = BasePayPal & RequiredServiceProperties & RequiredPayPalProperties

enum PayPalEnvironment: String {
    case sandbox
    case production
}

enum PayPalComponent {
    case product(PayPalEnvironment)
    case api(PayPalEnvironment)

    var category: String {
        switch self {
        case .product: return "product"
        case .api: return "api"
        }
    }

    var environment: PayPalEnvironment {
        switch self {
        case let .product(environment): return environment
        case let .api(environment): return environment
        }
    }
}

protocol RequiredPayPalProperties {
    var component: PayPalComponent { get }
}

class BasePayPal: BaseIndependentService {
    private enum PayPalStatus: String, ComparableStatus {
        case operational
        case underMaintenance = "under_maintenance"
        case serviceDisruption = "service_disruption"
        case serviceOutage = "service_outage"
        case informational

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational, .informational:
                return .good
            case .underMaintenance:
                return .maintenance
            case .serviceDisruption:
                return .minor
            case .serviceOutage:
                return .major
            }
        }

        var statusMessage: String {
            switch self {
            case .operational, .informational: return "Operational"
            case .underMaintenance: return "Under Maintenance"
            case .serviceDisruption: return "Service Disruption"
            case .serviceOutage: return "Service Outage"
            }
        }
    }

    var url: URL {
        guard let paypal = self as? PayPal else { fatalError("BasePayPal should not be used directly") }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.paypal-status.com"
        components.path = "/\(paypal.component.category)/\(paypal.component.environment.rawValue)"
        return components.url!
    }

    override func updateStatus() async throws {
        guard let realSelf = self as? PayPal else { fatalError("BasePayPal should not be used directly.") }

        let apiURL = URL(string: "https://www.paypal-status.com/api/v1/components")!
        let data = try await rawData(from: apiURL)

        guard
            let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let resultArray = dict["result"] as? [[String: Any]]
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let statuses = resultArray.compactMap {
            status(fromResultItem: $0, component: realSelf.component)
        }

        guard let worstStatus = statuses.max() else {
            throw StatusUpdateError.decodingError(nil)
        }

        statusDescription = ServiceStatusDescription(
            status: worstStatus.serviceStatus,
            message: worstStatus.statusMessage
        )
    }

    private func status(fromResultItem resultItem: [String: Any], component: PayPalComponent) -> PayPalStatus? {
        guard
            let categoryDict = resultItem["category"] as? [String: Any],
            categoryDict["name"] as? String == component.category,
            let statusDict = resultItem["status"] as? [String: String],
            let statusString = statusDict[component.environment.rawValue]
        else { return nil }

        let sanitizedStatusString = statusString.replacingOccurrences(of: " ", with: "_").lowercased()
        return PayPalStatus(rawValue: sanitizedStatusString)
    }
}
