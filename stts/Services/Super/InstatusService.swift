//
//  InstatusService.swift
//  stts
//

import Foundation
import Kanna

class InstatusServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "instatus"

    func build() -> BaseService? {
        InstatusService(self)
    }
}

class InstatusService: Service {
    private struct Site: Codable {
        let status: Status
        let components: [Component]

        enum Status: String, Codable {
            case up = "UP"
            case hasIssues = "HASISSUES"
        }
    }

    private struct Component: Codable {
        let name: Name
        let status: Status?
        let children: [Component]?

        /// The status of the current component and its children if any
        var effectiveStatus: ServiceStatus {
            if let children, let firstChild = children.first {
                return children.map { $0.effectiveStatus }.max() ?? firstChild.effectiveStatus
            } else if let status {
                return status.status
            } else {
                return .undetermined
            }
        }

        var affectedComponentsNames: [String] {
            if let children, !children.isEmpty {
                return children
                    .filter { $0.status != nil && $0.status != .operational }
                    .flatMap { $0.affectedComponentsNames }
                    .map { "\(name): \($0)"}
            } else if status != nil, status != .operational {
                return [name.default]
            } else {
                return []
            }
        }

        struct Name: Codable {
            let `default`: String
        }

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
        let name: Name
        let status: Status

        var isUnresolved: Bool {
            switch status {
            case .investigating, .identified, .monitoring:
                return true
            case .resolved:
                return false
            }
        }

        struct Name: Codable {
            let `default`: String
        }

        enum Status: String, Codable {
            case investigating = "INVESTIGATING"
            case identified = "IDENTIFIED"
            case monitoring = "MONITORING"
            case resolved = "RESOLVED"
        }
    }

    private struct InstatusData: Codable {
        let site: Site
        let activeIncidents: [Incident]
    }

    let name: String
    let url: URL

    init(_ definition: InstatusServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        var statusData: InstatusData?

        let scriptTags = doc.css("script")
        for scriptTag in scriptTags {
            guard let rawHTML = scriptTag.innerHTML else { continue }

            if rawHTML.contains("activeIncidents") {
                // swiftlint:disable:next force_try
                let regularExpression = try! NSRegularExpression(
                    pattern: "\\{.*\\}",
                    options: [.caseInsensitive, .dotMatchesLineSeparators]
                )
                guard let firstMatch = regularExpression.firstMatch(
                    in: rawHTML,
                    range: NSRange(location: 0, length: (rawHTML as NSString).length)
                ) else { continue }

                let json = (rawHTML as NSString).substring(with: firstMatch.range).unescaped
                guard let jsonData = json.data(using: .utf8) else {
                    continue
                }

                let dictionary = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                let children = dictionary?["children"] as? [Any]

                if let dataObject = children?.last as? [String: Any],
                   let dataObjectJSON = try? JSONSerialization.data(withJSONObject: dataObject) {
                    statusData = try? JSONDecoder().decode(InstatusData.self, from: dataObjectJSON)
                    if statusData != nil {
                        break
                    }
                }
            }
        }

        guard let statusData else {
            throw StatusUpdateError.decodingError(nil)
        }

        setStatus(from: statusData)
    }

    private func setStatus(from statusData: InstatusData) {
        let status = serviceStatus(
            for: statusData.site,
            components: statusData.site.components
        )

        // Set the message by combining the unresolved incident names
        let unresolvedIncidents = statusData.activeIncidents.filter { $0.isUnresolved }
        if !unresolvedIncidents.isEmpty {
            let prefix = unresolvedIncidents.count > 1 ? "* " : ""
            let message = unresolvedIncidents.map { "\(prefix)\($0.name.default)" }.joined(separator: "\n")
            statusDescription = ServiceStatusDescription(status: status, message: message)
            return
        }

        // Or from affected the component names
        let affectedComponents = statusData.site.components.flatMap { $0.affectedComponentsNames }
        if !affectedComponents.isEmpty {
            let message = affectedComponents.joined(separator: "\n")
            statusDescription = ServiceStatusDescription(status: status, message: message)
            return
        }

        // Fallback to the status description
        let message: String
        switch statusData.site.status {
        case .up:
            message = "All systems operational"
        case .hasIssues:
            message = "Experiencing issues"
        }
        statusDescription = ServiceStatusDescription(status: status, message: message)
    }

    private func serviceStatus(
        for site: Site,
        components: [Component]
    ) -> ServiceStatus {
        switch site.status {
        case .up:
            return .good
        case .hasIssues:
            return components.map { $0.effectiveStatus }.max() ?? .undetermined
        }
    }
}
