//
//  GitHub.swift
//  stts
//

import Foundation

class GitHub: Service {
    private enum GitHubStatus: String {
        case good
        case minor
        case major

        var serviceStatus: ServiceStatus {
            switch self {
            case .good:
                return .good
            case .minor:
                return .minor
            case .major:
                return .major
            }
        }
    }

    let url = URL(string: "https://status.github.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let lastMessageURL = URL(string: "https://status.github.com/api/last-message.json")!

        URLSession.shared.dataTask(with: lastMessageURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard
                let dict = json as? [String: String],
                let statusString = dict["status"],
                let status = GitHubStatus(rawValue: statusString)
            else { return strongSelf._fail("Unexpected data") }

            self?.status = status.serviceStatus
            self?.message = dict["body"] ?? ""
        }.resume()
    }
}
