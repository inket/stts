//
//  CloudFlare.swift
//  stts
//

import Cocoa

class CloudFlare: StatusPageService {
    override var url: URL { return URL(string: "https://www.cloudflarestatus.com")! }
    override var statusPageID: String { return "yh6f0r4529hb" }
}
