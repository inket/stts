//
//  OracleNetSuite.swift
//  stts
//

import Foundation

private struct NetSuiteResponse: Codable {
    struct NetSuiteStatus: Codable {
        enum Indicator: String, Codable {
            case none
            case minor
            case major
            case critical
            case maintenance

            var serviceStatus: ServiceStatus {
                switch self {
                case .none:
                    return .good
                case .minor:
                    return .minor
                case .major, .critical:
                    return .major
                case .maintenance:
                    return .maintenance
                }
            }
        }

        let indicator: Indicator
        let description: String
    }

    let status: NetSuiteStatus
}

class OracleNetSuite: IndependentService {
    let name = "Oracle NetSuite"
    let url = URL(string: "https://status.netsuite.com")!

    override func updateStatus() async throws {
        let response = try await decoded(NetSuiteResponse.self, from: url.appendingPathComponent("api/v2/status.json"))

        statusDescription = ServiceStatusDescription(
            status: response.status.indicator.serviceStatus,
            message: response.status.description
        )
    }
}
