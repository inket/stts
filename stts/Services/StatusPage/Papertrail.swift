//
//  Papertrail.swift
//  stts
//

import Foundation

class Papertrail: StatusPageService {
    override var url: URL { return URL(string: "http://www.papertrailstatus.com")! }
    override var statusPageID: String { return "0n5jhb30j32t" }
}
