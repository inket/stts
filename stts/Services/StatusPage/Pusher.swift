//
//  Pusher.swift
//  stts
//

import Cocoa

class Pusher: StatusPageService {
    override var name: String { return "Pusher" }
    override var url: URL { return URL(string: "https://status.pusher.com/")! }
    override var statusPageID: String { return "p6t5x7tdq8yq" }
}
