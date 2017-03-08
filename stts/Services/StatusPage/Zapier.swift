//
//  Zapier.swift
//  stts
//

import Foundation

class Zapier: StatusPageService {
    override var url: URL { return URL(string: "https://status.zapier.com")! }
    override var statusPageID: String { return "vg334k121155" }
}
