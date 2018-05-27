//
//  Gandi.swift
//  stts
//

import Foundation

class Gandi: Service {
    private enum GandiStatus: String, Codable {
        // Schema is at https://status.gandi.net/api/status/schema
        case sunny = "SUNNY"
        case cloudy = "CLOUDY"
        case foggy = "FOGGY"
        case stormy = "STORMY"

        var serviceStatus: ServiceStatus {
            switch self {
            case .sunny:
                return .good
            case .cloudy:
                return .maintenance
            case .foggy:
                return .minor
            case .stormy:
                return .major
            }
        }

        var statusMessage: String {
            switch self {
            case .sunny:
                return "All services are up and running"
            case .cloudy:
                return "A scheduled maintenance ongoing"
            case .foggy:
                return "Incident which are not impacting our services."
            case .stormy:
                return "An incident ongoing"
            }
        }
    }

    let name = "Gandi.net"
    let url = URL(string: "https://status.gandi.net")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let statusURL = URL(string: "https://status.gandi.net/api/status")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            // Schema is at https://status.gandi.net/api/status/schema
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String: String] else { return selfie._fail("Unexpected data") }

            guard
                let rawStatusString = dict["status"],
                let status = GandiStatus(rawValue: rawStatusString)
            else {
                return selfie._fail("Unexpected data")
            }

            self?.status = status.serviceStatus
            self?.message = status.statusMessage
        }.resume()
    }
}
