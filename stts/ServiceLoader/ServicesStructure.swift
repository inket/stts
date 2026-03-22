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
            miroServices
        ]

        return sections.compactMap { $0 }.flatMap { $0 }
    }
}
