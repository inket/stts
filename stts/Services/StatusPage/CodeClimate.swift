//
//  CodeClimate.swift
//  stts
//

import Foundation

class CodeClimate: StatusPageService {
    override var name: String { return "Code Climate" }
    override var url: URL { return URL(string: "http://status.codeclimate.com")! }
    override var statusPageID: String { return "rh2cj4bllp8l" }
}
