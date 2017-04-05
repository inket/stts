//
//  CodecovIO.swift
//  stts
//

import Foundation

class Codecov: StatusPageService {
    override var url: URL { return URL(string: "http://status.codecov.io")! }
    override var statusPageID: String { return "wdzsn5dlywj9" }
}
