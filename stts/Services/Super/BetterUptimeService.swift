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

        var iconCSSClass: String {
            switch self {
            case .operational:
                return "text-statuspage-green"
            case .degraded:
                return "text-statuspage-yellow"
            case .downtime:
                return "text-statuspage-red"
            case .maintenance:
                return "text-statuspage-blue"
            case .notMonitored:
                return "not-supported-in-v2-maybe?-make-an-issue-if-wrong"
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

            let status: ServiceStatus
            if let overviewElement = doc.css(".status-page__overview").first {
                // v1 page
                if let iconElement = overviewElement.css(".status-page__overview-icon").first {
                    status = self?.status(from: iconElement)?.serviceStatus ?? .undetermined
                } else {
                    status = .undetermined
                }
            } else if let headerIconElement = doc.css("h1 svg").first {
                // v2 page
                status = self?.status(fromV2Icon: headerIconElement)?.serviceStatus ?? .undetermined
            } else {
                return strongSelf._fail("Unexpected response")
            }

            let message =
                doc.css("h1").first?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unexpected response"

            strongSelf.statusDescription = ServiceStatusDescription(status: status, message: message)
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

    private func status(fromV2Icon element: XMLElement) -> BetterUptimeStatus? {
        guard let className = element.className, !className.isEmpty else { return nil }

        for statusCase in BetterUptimeStatus.allCases {
            if className.contains(statusCase.iconCSSClass) {
                return statusCase
            }
        }

        return nil
    }
}
