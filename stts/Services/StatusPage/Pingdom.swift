//
//  Pingdom.swift
//  stts
//

import Foundation

class Pingdom: StatusPageService {
    override var url: URL { return URL(string: "https://status.pingdom.com")! }
    override var statusPageID: String { return "71g81m9gdvs5" }
}
