//
//  SauceLabs.swift
//  stts
//

import Foundation

class SauceLabs: StatusPageService {
    override var url: URL { return URL(string: "https://status.saucelabs.com")! }
    override var statusPageID: String { return "kd2w7ghdk56w" }
}
