//
//  PlayStationNetwork.swift
//  stts
//

import Foundation

typealias PlayStationNetwork = BasePlayStationNetwork & RequiredServiceProperties & RequiredPlayStationNetworkProperties

enum PlayStationNetworkRegion: String {
    // from app.json
    case scea
    case scee
    case sceja

    var apiURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "status.playstation.com"
        components.path = "/data/statuses/region/\(rawValue.uppercased()).json"
        return components.url!
    }
}

protocol RequiredPlayStationNetworkProperties {
    var region: PlayStationNetworkRegion { get }
}

class BasePlayStationNetwork: BaseService {
    struct Response: Codable {
        struct Status: Codable {
            enum StatusType: String, Codable {
                case outage = "Outage"
                case degraded = "Degraded"
                case maintenance = "Maintenance"
                case ok = "OK"
            }

            let statusId: String
            let statusType: StatusType
        }

        let regionName: String
        let status: [Status]
    }

    let url = URL(string: "https://status.playstation.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? PlayStationNetwork else {
            fatalError("BasePlayStationNetwork should not be used directly.")
        }

        loadData(with: realSelf.region.apiURL) { [weak realSelf] data, _, error in
            guard let strongSelf = realSelf else { return }

            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
                return strongSelf._fail("Unexpected data")
            }

            let statusType = response.status.first?.statusType ?? .ok

            let status: ServiceStatus
            let message: String
            switch statusType {
            case .degraded:
                status = .minor
                message = "Some services are experiencing issues."
            case .outage:
                status = .major
                message = "Some services are experiencing issues."
            case .maintenance:
                status = .maintenance
                message = "Some services are undergoing scheduled maintenance."
            case .ok:
                status = .good
                message = "All services are up and running."
            }
            strongSelf.statusDescription = ServiceStatusDescription(status: status, message: message)
        }
    }
}
