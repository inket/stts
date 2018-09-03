//
//  Robinhood.swift
//  stts
//

import Foundation

class Robinhood: StatusPageService {
    override var url: URL { return URL(string: "http://status.robinhood.com")! }
    override var statusPageID: String { return "49plxygx5s1k" }
}
