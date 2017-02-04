//
//  Waffle.swift
//  stts
//

import Foundation

class Waffle: StatusPageService {
    override var name: String { return "Waffle.io" }
    override var url: URL { return URL(string: "http://status.waffle.io")! }
    override var statusPageID: String { return "zj1knmnzkg3f" }
}
