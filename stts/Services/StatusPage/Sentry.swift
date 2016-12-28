//
//  Sentry.swift
//  stts
//

import Foundation

class Sentry: StatusPageService {
    override var url: URL { return URL(string: "https://status.sentry.io")! }
    override var statusPageID: String { return "t687h3m0nh65" }
}
