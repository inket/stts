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
     Version 1 (.heading-large):
         :root {
             /* light mode colors in RGB */
             --color-green: 5, 150, 105; #059669
             --color-red: 185, 28, 28; #b91c1c
             --color-blue: 3, 105, 161; #0369a1
             --color-yellow: 217, 119, 6; #d97706
         }

         There are no class names or any indication about the service status since the status icon is sent as inline SVG.
         However, we can use the fill color to extrapolate the status.

     Version 2 (.heading-small):
         The SVG element has a CSS class indicating the status color:
             .text-statuspage-green, .text-statuspage-red, .text-statuspage-blue, .text-statuspage-yellow
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

    private enum StatusIconClass: String {
        case green = "text-statuspage-green"
        case red = "text-statuspage-red"
        case blue = "text-statuspage-blue"
        case yellow = "text-statuspage-yellow"

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

        if let heading = doc.css(".heading-large").first {
            try updateStatusV1(heading: heading)
        } else if let heading = doc.css(".heading-small").first {
            try updateStatusV2(heading: heading)
        } else {
            throw StatusUpdateError.decodingError(nil)
        }
    }

    private func updateStatusV1(heading: Kanna.XMLElement) throws {
        guard
            let statusMessage = heading.text?.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func updateStatusV2(heading: Kanna.XMLElement) throws {
        guard
            let statusMessage = heading.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let svgClassAttr = heading.parent?.css("svg").first?.className
        else {
            throw StatusUpdateError.decodingError(nil)
        }

        let svgClasses = svgClassAttr.components(separatedBy: .whitespaces)
        guard let statusIconClass = svgClasses.lazy.compactMap({ StatusIconClass(rawValue: $0) }).first else {
            throw StatusUpdateError.decodingError(nil)
        }

        statusDescription = ServiceStatusDescription(
            status: statusIconClass.serviceStatus,
            message: statusMessage
        )
    }
}
