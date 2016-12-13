//
//  BitBucket.swift
//  stts
//

import Cocoa

class BitBucket: StatusPageService {
    override var name: String { return "BitBucket" }
    override var url: URL { return URL(string: "https://status.bitbucket.org")! }
    override var statusPageID: String { return "bqlf8qjztdtr" }
}
