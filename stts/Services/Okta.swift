//
//  Okta.swift
//  stts
//

import Foundation
import Kanna

class Okta: Service {
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
    private let renderer = HeadlessHTMLRenderer()

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        renderer.retrieveRenderedHTML(for: url) { [weak self] html in
            guard let self else { return }
            defer { callback(self) }

            guard let html, !html.isEmpty else {
                return self._fail("No response")
            }

            guard let doc = try? HTML(html: html, encoding: .utf8) else {
                return self._fail("Couldn't parse response")
            }

            guard
                let todayIcon = doc.css(".today_icon").first,
                let todayIconClassNames = todayIcon.className?.components(separatedBy: .whitespaces),
                !todayIconClassNames.isEmpty
            else {
                return self._fail("Unexpected response")
            }

            let status: ServiceStatus? = Status.allCases.first(where: {
                todayIconClassNames.contains($0.iconClassName)
            })?.serviceStatus
            let message: String? = doc.css(".system__status_today_status").first?.text

            self.statusDescription = ServiceStatusDescription(
                status: status ?? .undetermined,
                message: message ?? "Unexpected response"
            )
        }
    }
}
