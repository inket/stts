//
//  Fabric.swift
//  stts
//

import Foundation

class Fabric: StatusPageService {
    override var url: URL { return URL(string: "http://status.fabric.io")! }
    override var statusPageID: String { return "rgxg3s525v7p" }
}
