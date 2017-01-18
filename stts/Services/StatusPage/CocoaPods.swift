//
//  CocoaPods.swift
//  stts
//

import Foundation

class CocoaPods: StatusPageService {
    override var url: URL { return URL(string: "https://status.cocoapods.org")! }
    override var statusPageID: String { return "7k11xygtyyyg" }
}
