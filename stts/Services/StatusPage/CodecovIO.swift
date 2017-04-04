//
//  CodecovIO.swift
//  stts
//

import Foundation

class CodecovIO: StatusPageService {
    override var url: URL { return URL(string: "http://status.codecov.io")! }
    override var statusPageID: String { return "wdzsn5dlywj9" }
}
