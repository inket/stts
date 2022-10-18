//
//  BetterUptimeService.swift
//  stts
//

import Kanna

typealias BetterUptimeService = BaseBetterUptimeService & RequiredServiceProperties & RequiredBetterUptimeProperties

protocol RequiredBetterUptimeProperties {}

class BaseBetterUptimeService: BaseService {
    private enum BetterUptimeStatus: String, CaseIterable {
        case operational
        case degraded
        case downtime
        case maintenance
        case notMonitored = "not-monitored"

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .degraded:
                return .minor
            case .downtime:
                return .major
            case .maintenance:
                return .maintenance
            case .notMonitored:
                return .notice
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? BetterUptimeService else {
            fatalError("BaseBetterUptimeService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            guard let overviewElement = doc.css(".status-page__overview").first else {
                return strongSelf._fail("Unexpected response")
            }

            if let iconElement = overviewElement.css(".status-page__overview-icon").first {
                self?.status = self?.status(from: iconElement)?.serviceStatus ?? .undetermined
            } else {
                self?.status = .undetermined
            }
            self?.message = overviewElement.css(".status-page__title").first?.content ?? "Unexpected response"
        }
    }

    private func status(from element: XMLElement) -> BetterUptimeStatus? {
        guard let className = element.className, !className.isEmpty else { return nil }

        for statusCase in BetterUptimeStatus.allCases {
            if className.contains(statusCase.rawValue) {
                return statusCase
            }
        }

        return nil
    }
}
