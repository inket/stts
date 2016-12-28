//
//  Pusher.swift
//  stts
//

import Foundation

class Pusher: StatusPageService {
    override var url: URL { return URL(string: "https://status.pusher.com/")! }
    override var statusPageID: String { return "p6t5x7tdq8yq" }
}
