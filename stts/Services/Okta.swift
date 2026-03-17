//
//  Okta.swift
//  stts
//

import Foundation
import Kanna

class Okta: IndependentService {
    private enum Status: CaseIterable {
        case operational
        case serviceDegradation
        case thirdPartyImpact
        case serviceDisruption

        var iconClassName: String {
            switch self {
            case .operational:
                return "icon-Success"
            case .serviceDegradation:
                return "icon-Alert"
            case .thirdPartyImpact:
                return "icon-ThirdImpact"
            case .serviceDisruption:
                return "icon-Error"
            }
        }

        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .serviceDegradation, .thirdPartyImpact:
                return .minor
            case .serviceDisruption:
                return .major
            }
        }
    }

    let url = URL(string: "https://status.okta.com")!

    @MainActor
    private let renderer = HeadlessHTMLRenderer()

    override func updateStatus() async throws {
        let html = await renderer.retrieveRenderedHTML(for: url)

        guard let html, !html.isEmpty else { throw StatusUpdateError.parseError(nil) }

        guard let doc = try? HTML(html: html, encoding: .utf8) else {
            throw StatusUpdateError.parseError(nil)
        }

        guard
            let todayIcon = doc.css(".today_icon").first,
            let todayIconClassNames = todayIcon.className?.components(separatedBy: .whitespaces),
            !todayIconClassNames.isEmpty
        else {
            throw StatusUpdateError.parseError(nil)
        }

        let status: ServiceStatus = Status.allCases.first(where: {
            todayIconClassNames.contains($0.iconClassName)
        })?.serviceStatus ?? .undetermined
        let message: String = doc.css(".system__status_today_status").first?.text ?? "Unexpected response"

        statusDescription = ServiceStatusDescription(status: status, message: message)
    }
}
