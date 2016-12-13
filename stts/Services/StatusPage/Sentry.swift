//
//  Sentry.swift
//  stts
//

import Cocoa

class Sentry: StatusPageService {
    override var name: String { return "Sentry" }
    override var url: URL { return URL(string: "https://status.sentry.io")! }
    override var statusPageID: String { return "t687h3m0nh65" }
}
