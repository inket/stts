//
//  CStateService.swift
//  stts
//
//  Created by inket on 2023/05/17.
//  Copyright © 2023 inket. All rights reserved.
//

import Foundation

typealias CStateService = BaseCStateService & RequiredServiceProperties & RequiredCStateProperties

protocol RequiredCStateProperties {}

class BaseCStateService: BaseService {
    private enum CStateStatus: String, Codable {
        // https://github.com/cstate/cstate/blob/master/layouts/index.json
        case ok
        case down
        case disrupted
        case notice

        var description: String {
            // https://github.com/cstate/cstate/blob/master/i18n/en.yaml#L17-L24
            switch self {
            case .ok:
                return "No issues detected"
            case .down:
                return "Experiencing major issues"
            case .disrupted:
                return "Experiencing disruptions"
            case .notice:
                return "Please read announcement"
            }
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .ok:
                return .good
            case .down:
                return .minor
            case .disrupted:
                return .major
            case .notice:
                return .notice
            }
        }
    }

    private struct Response: Codable {
        struct System: Codable {
            let name: String
            let status: CStateStatus?
        }

        let summaryStatus: CStateStatus
        let systems: [System]
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? CStateService else {
            fatalError("BaseCStateService should not be used directly.")
        }

        let statusURL = realSelf.url.appendingPathComponent("index.json")

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let self else { return }
            defer { callback(self) }
            guard let data else { return self._fail(error) }

            guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
                return self._fail("Unexpected data")
            }

            self.statusDescription = ServiceStatusDescription(
                status: response.summaryStatus.serviceStatus,
                message: self.message(from: response)
            )
        }
    }

    private func message(from response: Response) -> String {
        let affectedSystems = response.systems.filter { $0.status != nil && $0.status != .ok }

        guard !affectedSystems.isEmpty else {
            return response.summaryStatus.description
        }

        var lines: [String] = []
        lines.append(response.summaryStatus.description)
        lines.append(contentsOf: affectedSystems.map { "* \($0.name)"})
        return lines.joined(separator: "\n")
    }
}
