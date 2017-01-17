//
//  PivotalTracker.swift
//  stts
//

import Foundation

class PivotalTracker: StatusPageService {
    override var name: String { return "Pivotal Tracker" }
    override var url: URL { return URL(string: "https://status.pivotaltracker.com")! }
    override var statusPageID: String { return "mjwp4vwtvdp8" }
}
