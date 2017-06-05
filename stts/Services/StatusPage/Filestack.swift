//
//  Filestack.swift
//  stts
//

import Foundation

class Filestack: StatusPageService {
    override var url: URL { return URL(string: "https://status.filestack.com")! }
    override var statusPageID: String { return "z8cjgbr8sqmh" }
}
