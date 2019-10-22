//
//  Python.swift
//  stts
//

import Foundation

class Python: StatusPageService {
    override var url: URL { return URL(string: "https://status.python.org/")! }
    override var statusPageID: String { return "2p66nmmycsj3" }
}
