//
//  Site24x7Service.swift
//  stts
//

import Foundation

typealias Site24x7Service = BaseSite24x7Service & RequiredServiceProperties & RequiredSite24x7Properties

protocol RequiredSite24x7Properties {
    // Can be found by searching for "enc_statuspage_id" in the status page HTML
    var encryptedStatusPageID: String { get }
}

private protocol RepresentableComponent {
    var displayName: String { get }
    var status: Site24x7Status { get }
}

private enum Site24x7Status: Int, Codable {
    case operational = 1
    case informational = 2
    case underMaintenance = 4 // 4 instead of 3 intentionally
    case degradedPerformance = 3
    case partialOutage = 5
    case majorOutage = 6

    var displayName: String {
        switch self {
        case .operational:
            return "Operational"
        case .informational:
            return "Informational"
        case .underMaintenance:
            return "Under Maintenance"
        case .degradedPerformance:
            return "Degraded Performance"
        case .partialOutage:
            return "Partial Outage"
        case .majorOutage:
            return "Major Outage"
        }
    }

    var status: ServiceStatus {
        switch self {
        case .operational:
            return .good
        case .informational:
            return .notice
        case .underMaintenance:
            return .maintenance
        case .degradedPerformance, .partialOutage:
            return .minor
        case .majorOutage:
            return .major
        }
    }
}

class BaseSite24x7Service: BaseService {
    private struct Response: Decodable {
        let data: ResponseData
    }

    private struct ResponseData: Decodable {
        enum CodingKeys: String, CodingKey {
            case currentStatus = "current_status"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var componentsArray = try container.nestedUnkeyedContainer(forKey: .currentStatus)

            var resultComponents = [RepresentableComponent]()

            while !componentsArray.isAtEnd {
                if let componentGroup = try? componentsArray.decode(ComponentGroup.self) {
                    resultComponents.append(componentGroup)
                } else if let component = try? componentsArray.decode(Component.self) {
                    resultComponents.append(component)
                }
            }

            if resultComponents.isEmpty {
                let context = DecodingError.Context(
                    codingPath: [CodingKeys.currentStatus],
                    debugDescription: "No components found in current_status"
                )
                throw DecodingError.valueNotFound(ResponseData.self, context)
            }

            components = resultComponents
        }

        let components: [RepresentableComponent]
    }

    private struct ComponentGroup: Codable, RepresentableComponent {
        enum CodingKeys: String, CodingKey {
            case displayName = "componentgroup_display_name"
            case components = "componentgroup_components"
            case status = "componentgroup_status"
        }

        let displayName: String
        let components: [Component]
        let status: Site24x7Status
    }

    private struct Component: Codable, RepresentableComponent {
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case status = "component_status"
        }

        let displayName: String
        let status: Site24x7Status
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? Site24x7Service else {
            fatalError("BaseSite24x7Service should not be used directly.")
        }

        let apiURL = realSelf.url
            .appendingPathComponent("sp/api/public/summary_details/statuspages")
            .appendingPathComponent(realSelf.encryptedStatusPageID)

        loadData(with: apiURL) { [weak self] data, _, error in
            guard let self else { return }
            defer { callback(self) }
            guard let data = data else { return self._fail(error) }

            guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
                return self._fail("Unexpected response")
            }

            guard !response.data.components.isEmpty else { return self._fail("Unexpected response") }

            let status = self.status(for: response.data.components)
            self.status = status.status
            self.message = self.statusMessage(for: status, components: response.data.components)
        }
    }

    private func status(for components: [RepresentableComponent]) -> Site24x7Status {
        let flattenedComponents = components.flatMap { component -> [RepresentableComponent] in
            if let componentGroup = component as? ComponentGroup {
                return componentGroup.components
            } else {
                return [component]
            }
        }

        let worstComponent = flattenedComponents.max(by: { (one, two) -> Bool in
            one.status.status < two.status.status
        })! // We checked that it's not empty above
        return worstComponent.status
    }

    private func statusMessage(for status: Site24x7Status, components: [RepresentableComponent]) -> String {
        var message: [String] = []

        message.append(status.displayName)

        for component in components {
            if let componentGroup = component as? ComponentGroup {
                var addedGroupName = false

                for subcomponent in componentGroup.components where subcomponent.status != .operational {
                    if !addedGroupName {
                        message.append("* \(componentGroup.displayName)")
                        addedGroupName = true
                    }

                    message.append("   \(subcomponent.displayName)")
                }
            } else if component.status != .operational {
                message.append("* \(component.displayName)")
            }
        }

        return message.joined(separator: "\n")
    }
}
