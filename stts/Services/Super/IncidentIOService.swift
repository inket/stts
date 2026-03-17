//
//  IncidentIOService.swift
//  stts
//

import Foundation
import Kanna

class IncidentIOServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "incidentio"

    func build() -> BaseService? {
        IncidentIOService(self)
    }
}

class IncidentIOService: Service {
    private enum IncidentIOStatus: String {
        case operational
        case degradedPerformance = "degraded_performance"
        case partialOutage = "partial_outage"
        case fullOutage = "full_outage"
        case underMaintenance = "under_maintenance"

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .degradedPerformance:
                return .minor
            case .partialOutage:
                return .minor
            case .fullOutage:
                return .major
            case .underMaintenance:
                return .maintenance
            }
        }
    }

    let name: String
    let url: URL

    init(_ definition: IncidentIOServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    private func worstStatus(in html: String) -> IncidentIOStatus? {
        guard let regex = try? NSRegularExpression(pattern: #"current_status\\":\\"([a-z_]+)\\""#) else { return nil }
        var worst: IncidentIOStatus?
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            if let range = Range(match.range(at: 1), in: html),
               let status = IncidentIOStatus(rawValue: String(html[range])),
               worst == nil || status.serviceStatus > worst!.serviceStatus {
                worst = status
            }
        }
        return worst
    }

    private func affectedComponentIDs(in html: String) -> [String] {
        guard let blockRegex = try? NSRegularExpression(pattern: #"affected_components\\":\[(.*?)\]"#),
              let idRegex = try? NSRegularExpression(pattern: #"component_id\\":\\"([^\\"]+)\\""#) else { return [] }
        var ids: [String] = []
        for blockMatch in blockRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let blockRange = Range(blockMatch.range(at: 1), in: html) else { continue }
            let block = String(html[blockRange])
            for idMatch in idRegex.matches(in: block, range: NSRange(block.startIndex..., in: block)) {
                if let idRange = Range(idMatch.range(at: 1), in: block) {
                    let id = String(block[idRange])
                    if !ids.contains(id) { ids.append(id) }
                }
            }
        }
        return ids
    }

    private func componentIDToNameMap(in html: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"\\"id\\":\\"([^\\"]+)\\",\\"name\\":\\"([^\\"]+)\\""#
        ) else { return [:] }
        var map: [String: String] = [:]
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            if let idRange = Range(match.range(at: 1), in: html),
               let nameRange = Range(match.range(at: 2), in: html) {
                map[String(html[idRange])] = String(html[nameRange])
            }
        }
        return map
    }

    override func updateStatus() async throws {
        let data = try await rawData(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw StatusUpdateError.parseError(nil)
        }

        let doc = try HTML(html: data, encoding: .utf8)

        guard html.contains("ongoing_incidents") else {
            throw StatusUpdateError.parseError(nil)
        }

        // Find the status text and icon from the header <li>
        var statusText = ""
        var headerIconName = ""
        for li in doc.css("li") {
            guard let svgClass = li.css("svg").first?.className,
                  let iconRange = svgClass.range(of: "text-icon-") else { continue }
            headerIconName = String(svgClass[iconRange.upperBound...])
                .components(separatedBy: " ").first ?? ""
            statusText = li.xpath("text()")
                .compactMap { $0.content?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined()
            break
        }

        guard !headerIconName.isEmpty else {
            throw StatusUpdateError.decodingError(nil)
        }

        if html.contains(#"ongoing_incidents\":[]"#) {
            statusDescription = ServiceStatusDescription(status: .good, message: statusText)
            return
        }

        guard let ongoingRange = html.range(of: "ongoing_incidents"),
              let foundStatus = worstStatus(in: String(html[ongoingRange.lowerBound...]))
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let idToName = componentIDToNameMap(in: html)
        let componentNames = affectedComponentIDs(in: String(html[ongoingRange.lowerBound...]))
            .compactMap { idToName[$0] }

        let message: String
        if !componentNames.isEmpty {
            let components = componentNames.map { "* \($0)" }.joined(separator: "\n")
            message = statusText.isEmpty ? components : "\(statusText)\n\(components)"
        } else {
            message = statusText
        }

        statusDescription = ServiceStatusDescription(status: foundStatus.serviceStatus, message: message)
    }
}
