//
//  SmartyStreets.swift
//  stts
//

import Foundation

class SmartyStreets: StatusPageService {
    override var url: URL { return URL(string: "http://status.smartystreets.com")! }
    override var statusPageID: String { return "q1z5r94tnt56" }
}
