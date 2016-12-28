//
//  KeenIO.swift
//  stts
//

import Foundation

class KeenIO: StatusPageService {
    override var url: URL { return URL(string: "https://status.keen.io")! }
    override var statusPageID: String { return "z3mvdbpvy7yh" }
}
