//
//  HipChat.swift
//  stts
//

import Foundation

class HipChat: StatusPageService {
    override var url: URL { return URL(string: "https://status.hipchat.com")! }
    override var statusPageID: String { return "lgt1kx2s9x9s" }
}
