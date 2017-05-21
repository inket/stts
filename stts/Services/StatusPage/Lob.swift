//
//  Lob.swift
//  stts
//

import Foundation

class Lob: StatusPageService {
    override var url: URL { return URL(string: "http://status.lob.com")! }
    override var statusPageID: String { return "2xkb3rfdd3lg" }
}
