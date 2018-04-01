//
//  Unsplash.swift
//  stts
//

import Foundation

class Unsplash: StatusPageService {
    override var url: URL { return URL(string: "https://status.unsplash.com")! }
    override var statusPageID: String { return "gcw6g25tpdkv" }
}
