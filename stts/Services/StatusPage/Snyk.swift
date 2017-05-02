//
//  Snyk.swift
//  stts
//

import Foundation

class Snyk: StatusPageService {
    override var url: URL { return URL(string: "https://snyk.statuspage.io")! }
    override var statusPageID: String { return "myj6w6kw42c6" }
}
