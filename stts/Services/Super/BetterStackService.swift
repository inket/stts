//
//  BetterStackService.swift
//  stts
//

import Foundation
import Kanna

class BetterStackServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = "betterstack"

    func build() -> BaseService? {
        BetterStackService(self)
    }
}

class BetterStackService: Service {
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

    let name: String
    let url: URL

    init(_ definition: BetterStackServiceDefinition) {
        name = definition.name
        url = definition.url
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        guard
            let heading = doc.css(".heading-large").first,
            let statusMessage = heading.text,
            let statusIconFillColorString = heading.parent?.css("svg").first?.css("path").first?["fill"],
            let statusIconFillColor = StatusIconFillColor(rawValue: statusIconFillColorString.lowercased())
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        statusDescription = ServiceStatusDescription(
            status: statusIconFillColor.serviceStatus,
            message: statusMessage
        )
    }
}
