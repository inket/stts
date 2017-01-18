//
//  Coveralls.swift
//  stts
//

import Foundation

class Coveralls: StatusPageService {
    override var url: URL { return URL(string: "http://status.coveralls.io")! }
    override var statusPageID: String { return "3h72wtpg5fqs" }
}
