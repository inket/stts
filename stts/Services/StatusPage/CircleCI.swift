//
//  CircleCI.swift
//  stts
//

import Cocoa

class CircleCI: StatusPageService {
    override var url: URL { return URL(string: "https://status.circleci.com/")! }
    override var statusPageID: String { return "6w4r0ttlx5ft" }
}
