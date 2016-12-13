//
//  NPM.swift
//  stts
//

import Cocoa

class NPM: StatusPageService {
    override var name: String { return "NPM" }
    override var url: URL { return URL(string: "http://status.npmjs.org")! }
    override var statusPageID: String { return "wyvgptkd90hm" }
}
