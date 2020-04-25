//
//  AuthorizeNet.swift
//  stts
//

import Foundation

class AuthorizeNet: Service {
    let name = "Authorize.Net"
    let url = URL(string: "https://status.authorize.net")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let apiURL = URL(string: "https://status.authorize.net/status/v1/products/3/components")!

        loadData(with: apiURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }

            guard let response = try? JSONDecoder().decode(AuthorizeNetResponse.self, from: data) else {
                return strongSelf._fail("Unexpected data")
            }

            let worstComponent = response.responseData.componentList.max {
                $0.componentStatus.status < $1.componentStatus.status
            }

            guard let component = worstComponent else { return strongSelf._fail("Unexpected error") }

            strongSelf.status = component.componentStatus.status
            strongSelf.message = component.componentStatus.message
        }
    }
}

private struct AuthorizeNetResponse: Codable {
    struct ResponseData: Codable {
        struct Component: Codable {
            enum Status: String, Codable {
                case operational = "1"
                case degradedSpeed = "2"
                case partialOutage = "3"
                case majorOutage = "4"

                var message: String {
                    switch self {
                    case .operational: return "Operational"
                    case .degradedSpeed: return "Degraded Speed"
                    case .partialOutage: return "Partial Outage"
                    case .majorOutage: return "Major Outage"
                    }
                }

                var status: ServiceStatus {
                    switch self {
                    case .operational: return .good
                    case .degradedSpeed, .partialOutage: return .minor
                    case .majorOutage: return .major
                    }
                }
            }

            let componentStatus: Status
        }

        let componentList: [Component]
    }

    let status: Int
    let responseData: ResponseData
}
