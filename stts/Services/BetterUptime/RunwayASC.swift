//
//  RunwayASC.swift
//  stts
//

import Foundation

final class RunwayASC: BetterUptimeService {
    let name = "Runway: App Store Connect"
    let url = URL(string: "https://www.runway.team/is-app-store-connect-down")!
    let apiURL = URL(string: "https://runway-asc.betteruptime.com")!
}
