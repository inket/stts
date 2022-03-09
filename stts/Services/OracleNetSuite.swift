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

class OracleNetSuite: Service {
    let name = "Oracle NetSuite"
    let url = URL(string: "https://status.netsuite.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url.appendingPathComponent("api/v2/status.json")) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let response = try? JSONDecoder().decode(NetSuiteResponse.self, from: data) else {
                return strongSelf._fail("Couldn't parse response")
            }

            self?.status = response.status.indicator.serviceStatus
            self?.message = response.status.description
        }
    }
}
