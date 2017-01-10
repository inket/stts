//
//  Squarespace.swift
//  stts
//

import Foundation

class Squarespace: StatusPageService {
    override var url: URL { return URL(string: "https://status.squarespace.com")! }
    override var statusPageID: String { return "1jkhm1drpysj" }
}
