//
//  Heroku.swift
//  stts
//

import Foundation

private struct HerokuStatusResponse: Codable {
    struct HerokuStatus: Codable {
        enum CodingKeys: String, CodingKey {
            case production = "Production"
            case development = "Development"
        }

        enum Status: String, Codable {
            case green
            case red
            case yellow
            case blue

            var status: ServiceStatus {
                switch self {
                case .green: return .good
                case .red: return .major
                case .yellow: return .minor
                case .blue: return .maintenance
                }
            }
        }

        let production: Status
        let development: Status
    }

    struct HerokuIssue: Codable {
        let title: String
    }

    let status: HerokuStatus
    let issues: [HerokuIssue]
}

class Heroku: Service {
    let url = URL(string: "https://status.heroku.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let statusURL = URL(string: "https://status.heroku.com/api/v3/current-status")!

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let statusResponse = try? JSONDecoder().decode(HerokuStatusResponse.self, from: data) else {
                return strongSelf._fail("Unexpected data")
            }

            let production = statusResponse.status.production
            let development = statusResponse.status.development

            guard let max = [production, development].max(by: { $0.status < $1.status }) else {
                // This will never happen
                return strongSelf._fail("Unexpected error")
            }

            let status = max.status

            // Prefer "production" status text except when it's green
            let representedStatus = production == .green ? development : production
            let statusText = representedStatus.rawValue.capitalized

            let message: String
            switch max {
            case .green:
                message = statusText
            default:
                // Get the title of the current issue if any
                message = statusResponse.issues.first?.title ?? statusText
            }

            strongSelf.statusDescription = ServiceStatusDescription(status: status, message: message)
        }
    }
}
