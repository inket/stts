//
//  Zwift.swift
//  stts
//

import Foundation

class Zwift: StatusPageService {
    override var url: URL { return URL(string: "https://status.zwift.com")! }
    override var statusPageID: String { return "sj50pfj5p1yv" }
}
