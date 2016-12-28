//
//  TravisCI.swift
//  stts
//

import Foundation

class TravisCI: StatusPageService {
    override var url: URL { return URL(string: "https://www.traviscistatus.com/")! }
    override var statusPageID: String { return "pnpcptp8xh9k" }
}
