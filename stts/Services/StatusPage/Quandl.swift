//
//  Quandl.swift
//  stts
//

import Foundation

class Quandl: StatusPageService {
    override var url: URL { return URL(string: "http://status.quandl.com")! }
    override var statusPageID: String { return "dyfxchz1hcb1" }
}
