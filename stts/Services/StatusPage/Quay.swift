//
//  Quay.swift
//  stts
//

import Foundation

class Quay: StatusPageService {
    override var url: URL { return URL(string: "http://status.quay.io")! }
    override var statusPageID: String { return "8szqd6w4s277" }
}
