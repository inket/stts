//
//  MiroAll.swift
//  stts

import Foundation
import Kanna

class MiroAll: IndependentService, ServiceCategory {
    let categoryName: String = "Miro"
    let subServiceSuperclass: any AnyObject.Type = MiroService.self

    let name = "Miro (All Regions)"
    let url = URL(string: "https://status.miro.com/")!

    private func serviceStatus(fromIconSuffix suffix: String) -> ServiceStatus {
        switch suffix {
        case "operational": return .good
        case "degraded-performance", "partial-outage": return .minor
        case "full-outage": return .major
        case "under-maintenance": return .maintenance
        default: return .undetermined
        }
    }

    private func iconSuffix(fromClassName className: String) -> String? {
        guard let range = className.range(of: "text-icon-") else { return nil }
        return String(className[range.upperBound...]).components(separatedBy: " ").first
    }

    override func updateStatus() async throws {
        let doc = try await html(from: url)

        var regions: [(name: String, status: ServiceStatus)] = []

        for item in doc.css("[data-testid='subpage-item']") {
            guard let href = item["href"] else { continue }
            let regionName = String(href.dropFirst()).uppercased()
            let svgClass = item.css("svg").first?.className ?? ""
            guard let suffix = iconSuffix(fromClassName: svgClass) else { continue }
            regions.append((name: regionName, status: serviceStatus(fromIconSuffix: suffix)))
        }

        guard !regions.isEmpty else { throw StatusUpdateError.parseError(nil) }

        let worstStatus = regions.map(\.status).max() ?? .undetermined

        guard worstStatus != .good else {
            statusDescription = ServiceStatusDescription(status: .good, message: "We\u{2019}re fully operational")
            return
        }

        let message = regions
            .filter { $0.status != .good }
            .map { "\($0.name): We\u{2019}re currently experiencing issues" }
            .joined(separator: "\n")

        statusDescription = ServiceStatusDescription(status: worstStatus, message: message)
    }
}
