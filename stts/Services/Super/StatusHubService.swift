//
//  StatusHubService.swift
//  stts
//

import Foundation

typealias StatusHubService = BaseStatusHubService & RequiredServiceProperties & RequiredStatusHubProperties

protocol RequiredStatusHubProperties {}

class BaseStatusHubService: BaseService {
    private struct StatusHubResponse: Codable {
        struct Counters: Codable {
            enum CodingKeys: String, CodingKey {
                case upCount = "count_status_1"
                case affectedCount = "count_status_2"
                case downCount = "count_status_3"
            }

            let upCount: Int
            let affectedCount: Int
            let downCount: Int
        }

        let counters: Counters
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusHubService else {
            fatalError("BaseStatusHubService should not be used directly.")
        }

        let statusURL = realSelf.url.appendingPathComponent("api/statuses")

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let response = try? JSONDecoder().decode(StatusHubResponse.self, from: data) else {
                return strongSelf._fail("Unexpected data")
            }

            strongSelf.updateStatus(from: response)
        }
    }

    private func updateStatus(from response: StatusHubResponse) {
        var status: ServiceStatus = .undetermined
        var messageComponents: [String] = []

        if response.counters.upCount > 0 {
            status = .good
            messageComponents.append("\(response.counters.upCount) up")
        }

        if response.counters.affectedCount > 0 {
            status = .minor
            messageComponents.append("\(response.counters.affectedCount) affected")
        }

        if response.counters.downCount > 0 {
            status = .major
            messageComponents.append("\(response.counters.downCount) down")
        }

        self.status = status

        let prefix: String

        switch status {
        case .good:
            prefix = "Operating normally"
            // We don't need the extra "X up" message when all is good
            messageComponents = []
        case .minor:
            prefix = "Performance issues"
        case .major:
            prefix = "Service disruption"
        default:
            prefix = "Unexpected response"
        }

        message = [prefix, messageComponents.joined(separator: ", ")].joined(separator: "\n")
    }
}
