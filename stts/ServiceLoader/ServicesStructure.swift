//
//  ServicesStructure.swift
//  stts
//

import Foundation

struct ServicesStructure: Codable {
    enum CodingKeys: String, CodingKey {
        case independentServices = "independent"
        case cachetServices = "cachet"
        case lambServices = "lamb"
        case sorryServices = "sorry"
        case statusCakeServices = "statuscake"
        case statusPageServices = "statuspage"
        case instatusServices = "instatus"
        case statusCastServices = "statuscast"
        case incidentIOServices = "incidentio"
        case statusioV1Services = "statusiov1"
        case statuspalServices = "statuspal"
        case site24x7Services = "site24x7"
        case cstateServices = "cstate"
        case statusHubServices = "statushub"
        case betterUptimeServices = "betteruptime"
        case betterStackServices = "betterstack"
        case sendbirdServices = "sendbird"
        case miroServices = "miro"
        case pagerDutyServices = "pagerduty"
        case azureServices = "azure"
        case azureDevOpsServices = "azuredevops"
        case firebaseServices = "firebase"
        case salesforceServices = "salesforce"
        case adobeServices = "adobe"
        case appleServices = "apple"
        case appleDeveloperServices = "appledeveloper"
        case googleCloudPlatformServices = "googlecloudplatform"
        case awsRegionServices = "awsregions"
        case awsNamedServices = "awsservices"
        case removedServices = "_removed"
        case tagBodies = "_tags"
    }

    let independentServices: [IndependentServiceDefinition]?
    let cachetServices: [CachetServiceDefinition]?
    let lambServices: [LambStatusServiceDefinition]?
    let sorryServices: [SorryServiceDefinition]?
    let statusCakeServices: [StatusCakeServiceDefinition]?
    let statusPageServices: [StatusPageServiceDefinition]?
    let instatusServices: [InstatusServiceDefinition]?
    let statusCastServices: [StatusCastServiceDefinition]?
    let incidentIOServices: [IncidentIOServiceDefinition]?
    let statusioV1Services: [StatusioV1ServiceDefinition]?
    let statuspalServices: [StatuspalServiceDefinition]?
    let site24x7Services: [Site24x7ServiceDefinition]?
    let cstateServices: [CStateServiceDefinition]?
    let statusHubServices: [StatusHubServiceDefinition]?
    let betterUptimeServices: [BetterUptimeServiceDefinition]?
    let betterStackServices: [BetterStackServiceDefinition]?
    let sendbirdServices: [SendbirdServiceDefinition]?
    let miroServices: [MiroServiceDefinition]?
    let pagerDutyServices: [PagerDutyServiceDefinition]?
    let azureServices: [AzureServiceDefinition]?
    let azureDevOpsServices: [AzureDevOpsServiceDefinition]?
    let firebaseServices: [FirebaseServiceDefinition]?
    let salesforceServices: [SalesforceServiceDefinition]?
    let adobeServices: [AdobeServiceDefinition]?
    let appleServices: [AppleServiceDefinition]?
    let appleDeveloperServices: [AppleDeveloperServiceDefinition]?
    let googleCloudPlatformServices: [GoogleCloudPlatformServiceDefinition]?
    let awsRegionServices: [AWSRegionServiceDefinition]?
    let awsNamedServices: [AWSServicesServiceDefinition]?

    /// Identifiers of services confirmed gone for good (company shut down/bankrupt, product
    /// discontinued) — not services that are merely renamed (see `old_names`) or just currently
    /// unreachable/broken (e.g. a dead domain for a company that's still very much operating; it
    /// might get a working integration again later, so it must NOT be listed here). Used to prune a
    /// user's stale preference for a service that will never come back, rather than leaving it
    /// silently unmatched forever.
    let removedServices: [String]?

    /// The category vocabulary, by `ServiceTag.id`.
    let tagBodies: [String: ServiceTag.Body]?

    var tags: [ServiceTag] {
        ServiceTag.tags(from: tagBodies ?? [:])
    }

    var allServices: [ServiceDefinition] {
        let sections: [[ServiceDefinition]?] = [
            independentServices,
            cachetServices,
            lambServices,
            sorryServices,
            statusCakeServices,
            statusPageServices,
            instatusServices,
            statusCastServices,
            incidentIOServices,
            statusioV1Services,
            statuspalServices,
            site24x7Services,
            cstateServices,
            statusHubServices,
            betterUptimeServices,
            betterStackServices,
            sendbirdServices,
            miroServices,
            pagerDutyServices,
            azureServices,
            azureDevOpsServices,
            firebaseServices,
            salesforceServices,
            adobeServices,
            appleServices,
            appleDeveloperServices,
            googleCloudPlatformServices,
            awsRegionServices,
            awsNamedServices
        ]

        return sections.compactMap { $0 }.flatMap { $0 }
    }
}
