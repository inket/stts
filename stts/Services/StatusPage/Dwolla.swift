//
//  Dwolla.swift
//  stts
//

import Foundation

class Dwolla: StatusPageService {
    override var url: URL { return URL(string: "http://status.dwolla.com")! }
    override var statusPageID: String { return "tnynfs0nwlgr" }
}
