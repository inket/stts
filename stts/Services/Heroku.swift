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

class Heroku: IndependentService {
    let url = URL(string: "https://status.heroku.com")!

    override func updateStatus() async throws {
        let statusURL = URL(string: "https://status.heroku.com/api/v3/current-status")!
        let statusResponse = try await decoded(HerokuStatusResponse.self, from: statusURL)

        let production = statusResponse.status.production
        let development = statusResponse.status.development

        let worstEnvironmentStatus = production.status > development.status ? production : development
        let status = worstEnvironmentStatus.status

        // Prefer "production" status text except when it's green
        let representedStatus = production == .green ? development : production
        let statusText = representedStatus.rawValue.capitalized

        let message: String
        switch worstEnvironmentStatus {
        case .green:
            message = statusText
        default:
            // Get the title of the current issue if any
            message = statusResponse.issues.first?.title ?? statusText
        }

        statusDescription = ServiceStatusDescription(status: status, message: message)
    }
}
