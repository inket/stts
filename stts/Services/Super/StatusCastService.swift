//
//  StatusCastService.swift
//  stts
//

import Foundation
import Kanna

typealias StatusCastService = BaseStatusCastService & RequiredServiceProperties & RequiredStatusCastProperties

protocol RequiredStatusCastProperties {
    var hasCurrentStatus: Bool { get }
}

class BaseStatusCastService: BaseService {
    private enum CurrentStatus: String, CaseIterable {
        case available
        case unavailable
        case informational
        case monitored
        case identified
        case investigating
        case degraded
        case maintenance

        var serviceStatus: ServiceStatus {
            switch self {
            case .available:
                return .good
            case .unavailable:
                return .major
            case .informational, .monitored, .identified:
                return .notice
            case .investigating, .degraded:
                return .minor
            case .maintenance:
                return .maintenance
            }
        }

        var className: String {
            "component-\(rawValue)"
        }
    }

    private enum IncidentStatus: String, CaseIterable {
        case available
        case informational
        case performance
        case unavailable

        var serviceStatus: ServiceStatus {
            switch self {
            case .available:
                return .good
            case .unavailable:
                return .major
            case .informational:
                return .notice
            case .performance:
                return .minor
            }
        }

        var incidentIconClassName: String {
            "component-\(rawValue)"
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusCastService else {
            fatalError("BaseStatusCastService should not be used directly.")
        }

        if realSelf.hasCurrentStatus {
            updateStatusWithCurrentStatus(realSelf: realSelf, callback: callback)
        } else {
            updateStatusWithIncidents(realSelf: realSelf, callback: callback)
        }
    }

    private func updateStatusWithCurrentStatus(realSelf: StatusCastService, callback: @escaping (BaseService) -> Void) {
        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            let statuses: [(ServiceStatus, String?)] = doc.css(".status-list-component-status-text").map { element in
                for status in CurrentStatus.allCases {
                    if element.className?.contains(status.className) == true {
                        return (
                            status.serviceStatus,
                            element.innerHTML?.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                }

                return (.undetermined, nil)
            }

            guard let worstStatus = statuses.max(by: { $0.0 < $1.0 }) else {
                return strongSelf._fail("Unexpected response")
            }

            strongSelf.statusDescription = ServiceStatusDescription(
                status: worstStatus.0,
                message: worstStatus.1 ?? "Unexpected response"
            )
        }
    }

    private func updateStatusWithIncidents(realSelf: StatusCastService, callback: @escaping (BaseService) -> Void) {
        guard var urlComponents = URLComponents(url: realSelf.url, resolvingAgainstBaseURL: false) else {
            fatalError("Invalid service URL: \(realSelf.url)")
        }
        urlComponents.path = "/incidents"
        urlComponents.queryItems = [
            URLQueryItem(name: "IncidentStatus", value: "OpenStarted")
        ]
        guard let url = urlComponents.url else {
            fatalError("Invalid service URL: \(urlComponents)")
        }

        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            let incidents = doc.css("#results .incident-body")
            if incidents.count == 0 {
                strongSelf.statusDescription = ServiceStatusDescription(status: .good, message: "Normal")
            } else {
                var statuses: [ServiceStatus] = []
                var messageComponents: [String] = []

                for incident in incidents {
                    let message = incident
                        .css(".incident-title")
                        .first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let message {
                        messageComponents.append(message)
                    }

                    let incidentIconClassNames = incident
                        .css(".incident-icon .fa")
                        .first?.className?
                        .components(separatedBy: .whitespaces) ?? []

                    let status = IncidentStatus.allCases.first {
                        incidentIconClassNames.contains($0.incidentIconClassName)
                    }

                    if let status {
                        statuses.append(status.serviceStatus)
                    }
                }

                if let maxStatus = statuses.max(), !messageComponents.isEmpty {
                    if messageComponents.count > 1 {
                        messageComponents = messageComponents.map { "* \($0)" }
                    }

                    strongSelf.statusDescription = ServiceStatusDescription(
                        status: maxStatus,
                        message: messageComponents.joined(separator: "\n")
                    )
                } else {
                    strongSelf._fail("Unexpected response")
                }
            }
        }
    }
}
