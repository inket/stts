//
//  InstatusService.swift
//  stts
//

import Kanna

typealias InstatusService = BaseInstatusService & RequiredServiceProperties & RequiredInstatusProperties

protocol RequiredInstatusProperties {}

class BaseInstatusService: BaseService {
    private struct Site: Codable {
        let status: Status
        let components: [Component]

        enum Status: String, Codable {
            case up = "UP"
            case hasIssues = "HASISSUES"
        }
    }

    private struct Component: Codable {
        let name: String
        let status: Status

        enum Status: String, Codable {
            case operational = "OPERATIONAL"
            case underMaintenance = "UNDERMAINTENANCE"
            case degradedPerformance = "DEGRADEDPERFORMANCE"
            case partialOutage = "PARTIALOUTAGE"
            case minorOutage = "MINOROUTAGE"
            case majorOutage = "MAJOROUTAGE"

            var status: ServiceStatus {
                switch self {
                case .operational:
                    return .good
                case .underMaintenance:
                    return .maintenance
                case .degradedPerformance:
                    return .notice
                case .partialOutage, .minorOutage:
                    return .minor
                case .majorOutage:
                    return .major
                }
            }
        }
    }

    private struct Incident: Codable {
        let name: String
        let status: Status

        var isUnresolved: Bool {
            switch status {
            case .investigating, .identified, .monitoring:
                return true
            case .resolved:
                return false
            }
        }

        enum Status: String, Codable {
            case investigating = "INVESTIGATING"
            case identified = "IDENTIFIED"
            case monitoring = "MONITORING"
            case resolved = "RESOLVED"
        }
    }

    private struct InstatusData: Codable {
        struct Props: Codable {
            struct PageProps: Codable {
                let site: Site
                let activeIncidents: [Incident]
            }

            let pageProps: PageProps
        }

        let props: Props
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? InstatusService else {
            fatalError("BaseInstatusService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }

            guard
                let doc = try? HTML(html: data, encoding: .utf8),
                let json = doc.css("#__NEXT_DATA__").first?.innerHTML,
                let jsonData = json.data(using: .utf8),
                let statusData = try? JSONDecoder().decode(InstatusData.self, from: jsonData)
            else {
                return strongSelf._fail("Couldn't parse response")
            }

            // Set the status
            self?.status = strongSelf.serviceStatus(
                for: statusData.props.pageProps.site,
                components: statusData.props.pageProps.site.components
            )

            // Set the message by combining the unresolved incident names
            let unresolvedIncidents = statusData.props.pageProps.activeIncidents.filter { $0.isUnresolved }
            if !unresolvedIncidents.isEmpty {
                let prefix = unresolvedIncidents.count > 1 ? "* " : ""
                self?.message = unresolvedIncidents.map { "\(prefix)\($0.name)" }.joined(separator: "\n")
                return
            }

            // Or from affected the component names
            let affectedComponents = statusData.props.pageProps.site.components.filter { $0.status != .operational }
            if !affectedComponents.isEmpty {
                let prefix = affectedComponents.count > 1 ? "* " : ""

                self?.message = affectedComponents
                    .map { "\(prefix)\($0.name)" }
                    .joined(separator: "\n")
                return
            }

            // Fallback to the status description
            switch statusData.props.pageProps.site.status {
            case .up:
                self?.message = "All systems operational"
            case .hasIssues:
                self?.message = "Experiencing issues"
            }
        }
    }

    private func serviceStatus(
        for site: Site,
        components: [Component]
    ) -> ServiceStatus {
        switch site.status {
        case .up:
            return .good
        case .hasIssues:
            return components.map { $0.status.status }.max() ?? .undetermined
        }
    }
}
