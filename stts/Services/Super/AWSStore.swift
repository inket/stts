//
//  AWSStore.swift
//  stts
//

import Foundation

// When all is good, the response from currentevents is empty; luckily I found this incident on web.archive.org:
//    [{
//        "date": "1678726651",
//        "region_name": "Oregon",
//        "status": "0",
//        "service": "internetconnectivity-us-west-2",
//        "service_name": "AWS Internet Connectivity",
//        "summary": "[RESOLVED] Internet Connectivity in the US-WEST-2 Region",
//        "event_log": [{
//            "summary": "[RESOLVED] Internet Connectivity in the US-WEST-2 Region",
//            "message": "Between 8:25 AM and 9:16 AM PDT, we experienced elevated packet loss and latency to a small set of internet destinations in the US-WEST-2 Region. Connectivity within the US-WEST-2 Region was not impacted. The issue has been resolved and the services are operating normally.",
//            "status": 1,
//            "timestamp": 1678726620
//        }],
//        "impacted_services": {
//            "elb-us-west-2": {
//                "service_name": "Amazon Elastic Load Balancing",
//                "current": "0",
//                "max": "1"
//            },
//            "natgateway-us-west-2": {
//                "service_name": "AWS NAT Gateway",
//                "current": "0",
//                "max": "1"
//            },
//            "ec2-us-west-2": {
//                "service_name": "Amazon Elastic Compute Cloud",
//                "current": "0",
//                "max": "1"
//            }
//        },
//        "end_time": "1678727476"
//    }]

struct AWSIncident: Codable {
    enum CodingKeys: String, CodingKey {
        case regionName = "region_name"
        case status
        case serviceID = "service"
        case serviceName = "service_name"
        case impactedServices = "impacted_services"
    }

    let regionName: String
    let status: String
    let serviceID: String
    let serviceName: String
    let impactedServices: [String: ImpactedService]

    func impactedServices(for service: AWSNamedService) -> Set<String> {
        var result = Set<String>()

        if service.ids.contains(serviceID) {
            result.insert(serviceID)
        }

        return result.union(service.ids.intersection(Set<String>(impactedServices.keys)))
    }

    struct ImpactedService: Codable {
        let name: String

        private enum CodingKeys: String, CodingKey {
            case name = "service_name"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        regionName = try container.decode(String.self, forKey: .regionName)
        if let statusString = try? container.decode(String.self, forKey: .status) {
            status = statusString
        } else {
            status = String(try container.decode(Int.self, forKey: .status))
        }
        serviceID = try container.decode(String.self, forKey: .serviceID)
        serviceName = try container.decode(String.self, forKey: .serviceName)
        impactedServices = try container.decode([String: ImpactedService].self, forKey: .impactedServices)
    }
}

class AWSStore: ServiceStore<[AWSIncident]> {
    private var url: URL

    init(url: URL) {
        self.url = url
    }

    override func retrieveUpdatedState() async throws -> [AWSIncident] {
        return try await decoded([AWSIncident].self, from: url)
    }

    func updatedStatus(for aws: AWSAllService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        var status: ServiceStatus = .good
        var impactedServiceNames = Set<String>()

        for incident in updatedState {
            guard incident.status != "0" else { continue }

            status = .minor

            impactedServiceNames.insert(incident.serviceName)
            for (_, impactedService) in incident.impactedServices {
                impactedServiceNames.insert(impactedService.name)
            }
        }

        return ServiceStatusDescription(
            status: status,
            message: message(for: status, impactedServiceNames: impactedServiceNames)
        )
    }

    func updatedStatus(for region: AWSRegionService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        var status: ServiceStatus = .good
        var impactedServiceNames = Set<String>()

        for incident in updatedState {
            guard incident.status != "0" else { continue }

            if incident.regionName == region.name {
                status = .minor

                impactedServiceNames.insert(incident.serviceName)
                for (_, impactedService) in incident.impactedServices {
                    impactedServiceNames.insert(impactedService.name)
                }
            }
        }

        return ServiceStatusDescription(
            status: status,
            message: message(for: status, impactedServiceNames: impactedServiceNames)
        )
    }

    func updatedStatus(for namedService: AWSNamedService) async throws -> ServiceStatusDescription {
        let updatedState = try await updatedState()

        var status: ServiceStatus = .good

        for incident in updatedState {
            guard incident.status != "0" else { continue }

            let impactedServiceIDs = incident.impactedServices(for: namedService)
            if !impactedServiceIDs.isEmpty {
                status = .minor
                break
            }
        }

        return ServiceStatusDescription(
            status: status,
            message: message(for: status, impactedServiceNames: nil)
        )
    }

    private func message(for status: ServiceStatus, impactedServiceNames: Set<String>?) -> String {
        let serviceNames = impactedServiceNames ?? []

        let message: String
        if serviceNames.isEmpty {
            switch status {
            case .good:
                message = "No recent issues"
            default:
                message = "Impacted"
            }
        } else {
            message = "Impacted services:\n" + serviceNames.joined(separator: "\n")
        }

        return message
    }
}
