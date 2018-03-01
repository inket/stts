//
//  Vimeo.swift
//  stts
//

import Foundation

class Vimeo: StatusPageService {
    override var url: URL { return URL(string: "http://status.vimeo.com")! }
    override var statusPageID: String { return "sccqh0pnqrh8" }
}
