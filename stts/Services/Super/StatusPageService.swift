//
//  StatusPageService.swift
//  stts
//

import Foundation

typealias StatusPageService = BaseStatusPageService & RequiredServiceProperties & RequiredStatusPageProperties

protocol RequiredStatusPageProperties {
    var statusPageID: String { get }
    var domain: String { get }
}

extension RequiredStatusPageProperties {
    var domain: String {
        return "statuspage.io"
    }
}

class BaseStatusPageService: BaseService {
    private enum StatusPageStatus: String {
        case none
        case minor
        case critical
        case major
        case maintenance

        var serviceStatus: ServiceStatus {
            switch self {
            case .none:
                return .good
            case .minor:
                return .minor
            case .critical,
                 .major:
                return .major
            case .maintenance:
                return .maintenance
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusPageService else { fatalError("BaseStatusPageService should not be used directly.") }

        let statusURL = URL(string: "https://\(realSelf.statusPageID).\(realSelf.domain)/api/v2/status.json")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard
                let dict = (json as? [String: Any])?["status"] as? [String: String],
                let statusString = dict["indicator"],
                let status = StatusPageStatus(rawValue: statusString.lowercased())
            else { return strongSelf._fail("Unexpected data") }

            self?.status = status.serviceStatus
            self?.message = dict["description"] ?? ""
        }.resume()
    }
}
