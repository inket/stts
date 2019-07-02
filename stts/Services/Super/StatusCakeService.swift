//
//  StatusCakeService.swift
//  stts
//

import Foundation

typealias StatusCakeService = BaseStatusCakeService & RequiredServiceProperties & RequiredStatusCakeProperties

protocol RequiredStatusCakeProperties {
    var publicID: String { get }
}

class BaseStatusCakeService: BaseService {
    private enum StatusCakeStatus: String, ComparableStatus {
        case up = "Up"
        case down = "Down"

        var description: String {
            return rawValue
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .up:
                return .good
            case .down:
                return .major
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? StatusCakeService else { fatalError("BaseStatusCakeService should not be used directly.") }

        let statusURL = URL(string: "https://app.statuscake.com/Workfloor/PublicReportHandler.php?PublicID=\(realSelf.publicID)")!

        loadData(with: statusURL) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard let testData = (json as? [String: Any])?["TestData"] as? [[String: Any]] else {
                return strongSelf._fail("Unexpected data")
            }

            let statuses = testData.compactMap { $0["Status"] as? String }.compactMap(StatusCakeStatus.init(rawValue:))
            let highestStatus = statuses.max()
            self?.status = highestStatus?.serviceStatus ?? .undetermined
            self?.message = highestStatus?.description ?? "Undetermined"
        }
    }
}
