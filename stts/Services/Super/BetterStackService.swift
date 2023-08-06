//
//  BetterStackService.swift
//  stts
//

import Foundation
import Kanna

typealias BetterStackService = BaseBetterStackService & RequiredServiceProperties & RequiredBetterStackProperties

protocol RequiredBetterStackProperties {}

class BaseBetterStackService: BaseService {
    /*
     :root {
         /* light mode colors in RGB */
         --color-green: 5, 150, 105; #059669
         --color-red: 185, 28, 28; #b91c1c
         --color-blue: 3, 105, 161; #0369a1
         --color-yellow: 217, 119, 6; #d97706
     }

     There are no class names or any indication about the service status since the status icon is sent as inline SVG.
     However, we can use the fill color to extrapolate the status.
    */

    private enum StatusIconFillColor: String {
        case green = "#059669"
        case red = "#b91c1c"
        case blue = "#0369a1"
        case yellow = "#d97706"

        var serviceStatus: ServiceStatus {
            switch self {
            case .green:
                return .good
            case .yellow:
                return .minor
            case .red:
                return .major
            case .blue:
                return .maintenance
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? BetterStackService else {
            fatalError("BaseBetterStackService should not be used directly.")
        }

        loadData(with: realSelf.url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            guard let data = data else { return strongSelf._fail(error) }

            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            guard
                let heading = doc.css(".heading-large").first,
                let statusMessage = heading.text,
                let statusIconFillColorString = heading.parent?.css("svg").first?.css("path").first?["fill"],
                let statusIconFillColor = StatusIconFillColor(rawValue: statusIconFillColorString.lowercased())
            else {
                return strongSelf._fail("Unexpected response")
            }

            strongSelf.statusDescription = ServiceStatusDescription(
                status: statusIconFillColor.serviceStatus,
                message: statusMessage
            )
        }
    }
}
