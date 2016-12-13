//
//  NewRelic.swift
//  stts
//

import Cocoa

class NewRelic: StatusPageService {
    override var name: String { return "New Relic" }
    override var url: URL { return URL(string: "https://status.newrelic.com")! }
    override var statusPageID: String { return "4qjjcrpdj8jh" }
}
