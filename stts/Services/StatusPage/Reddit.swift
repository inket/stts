//
//  Reddit.swift
//  stts
//

import Foundation

class Reddit: StatusPageService {
    override var url: URL { return URL(string: "https://www.redditstatus.com/")! }
    override var statusPageID: String { return "2kbc0d48tv3j" }
}
