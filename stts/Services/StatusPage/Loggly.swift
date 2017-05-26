//
//  Loggly.swift
//  stts
//

import Foundation

class Loggly: StatusPageService {
    override var url: URL { return URL(string: "http://status.loggly.com")! }
    override var statusPageID: String { return "701xnxqmhdh3" }
}
