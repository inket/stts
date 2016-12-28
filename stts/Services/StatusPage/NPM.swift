//
//  NPM.swift
//  stts
//

import Foundation

class NPM: StatusPageService {
    override var url: URL { return URL(string: "http://status.npmjs.org")! }
    override var statusPageID: String { return "wyvgptkd90hm" }
}
