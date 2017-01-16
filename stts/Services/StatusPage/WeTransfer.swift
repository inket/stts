//
//  WeTransfer.swift
//  stts
//

import Foundation

class WeTransfer: StatusPageService {
    override var url: URL { return URL(string: "https://wetransfer.statuspage.io/")! }
    override var statusPageID: String { return "sc26zwwp3c0r" }
}
