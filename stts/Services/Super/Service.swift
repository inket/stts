//
//  Service.swift
//  stts
//
//  Created by inket on 28/7/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa


enum ServiceStatus {
    case undetermined
    case good
    case minor
    case major
}

class Service {
    var name: String { return "Undefined" }
    var status: ServiceStatus = .undetermined
    var message: String = "Loading…"
    var url: URL { return URL(string: "")! }

    static func all() -> [Service] {
        let allServices = [
            GitHub.self,
            TravisCI.self,
            Heroku.self,
            CircleCI.self,
            NewRelic.self,
            AmazonWebServices.self,
            NPM.self,
            RubyGems.self,
            Pusher.self,
            Reddit.self,
            BitBucket.self,
            CloudFlare.self,
            Sentry.self,
            EngineYard.self
        ] as [Service.Type]

        return allServices.map { $0.init() }
    }

    required init() {}
    func updateStatus(callback: @escaping (Service) -> ()) {}
}

extension Service: Equatable {
    public static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.name == rhs.name
    }
}

extension Service: Comparable {
    static func < (lhs: Service, rhs: Service) -> Bool {
        let sameStatus = lhs.status == rhs.status
        let differentStatus = lhs.status != .good && rhs.status == .good
        return ((lhs.name < rhs.name) && sameStatus) || differentStatus
    }
}
