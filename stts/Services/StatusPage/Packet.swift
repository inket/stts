//
//  Packet.swift
//  stts
//
//

import Foundation

class Packet: StatusPageService {
    override var url: URL { return URL(string: "https://packet.statuspage.io")! }
    override var statusPageID: String { return "39f8vhy6rw5d" }
}
