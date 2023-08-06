//
//  Statuspal.swift
//  stts
//

import Foundation
import Kanna

typealias StatuspalService = BaseStatuspalService & RequiredServiceProperties & RequiredStatuspalProperties

protocol RequiredStatuspalProperties {}

class BaseStatuspalService: BaseService {
    private enum Status: CaseIterable {
        case good
        case minor
        case major
        case scheduled

        var className: String {
            switch self {
            case .good:
                return "type-none"
            case .minor:
                return "type-minor"
            case .major:
                return "type-major"
            case .scheduled:
                return "type-scheduled"
            }
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .good:
                return .good
            case .minor:
                return .minor
            case .major:
                return .major
            case .scheduled:
                return .notice
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatuspalService else {
            fatalError("BaseStatuspalService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            let foundStatus: ServiceStatus
            if let className = doc.css(".system-status").first?.className {
                let matchedStatus = Status.allCases.first { status in
                    className.lowercased().contains(status.className)
                }

                if let matchedStatus {
                    foundStatus = matchedStatus.serviceStatus
                } else {
                    foundStatus = .undetermined
                }
            } else {
                foundStatus = .undetermined
            }

            let message: String = doc.css(".system-status--description")
                .first?
                .text?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unexpected response"

            strongSelf.statusDescription = ServiceStatusDescription(status: foundStatus, message: message)
        }
    }
}
