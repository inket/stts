//
//  Rollbar.swift
//  stts
//

import Foundation

class Rollbar: StatusPageService {
    override var url: URL { return URL(string: "http://status.rollbar.com/")! }
    override var statusPageID: String { return "0hsb4m2rq2h3" }
}
