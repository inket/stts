//
//  Dropbox.swift
//  stts
//

import Foundation

class Dropbox: StatusPageService {
    override var url: URL { return URL(string: "https://status.dropbox.com")! }
    override var statusPageID: String { return "t34htyd6jblf" }
}
