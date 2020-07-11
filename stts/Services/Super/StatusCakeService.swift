//
//  StatusCakeService.swift
//  stts
//

import Foundation

struct StatusCakeServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case id
    }

    let name: String
    let url: URL
    let id: String

    var legacyIdentifier: String { name }
    var globalIdentifier: String { "cake.\(id)" }

    func build() -> BaseService? {
        StatusCakeService(self)
    }
}

class StatusCakeService: Service {
    let id: String
    let name: String
    let url: URL

    init(_ definition: StatusCakeServiceDefinition) {
        id = definition.id
        name = definition.name
        url = definition.url
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        let statusURL = URL(string: "https://app.statuscake.com/Workfloor/PublicReportHandler.php?PublicID=\(id)")!

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
