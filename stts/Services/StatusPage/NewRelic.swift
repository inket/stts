//
//  NewRelic.swift
//  stts
//

import Foundation

final class NewRelic: StatusPageService {
    let name = "New Relic"
    let url = URL(string: "https://status.newrelic.com")!
    let statusPageID = "nwg5xmnm9d17"
}
