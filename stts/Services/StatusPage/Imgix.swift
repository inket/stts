//
//  Imgix.swift
//  stts
//

import Foundation

class Imgix: StatusPageService {
    override var name: String { return "imgix" }
    override var url: URL { return URL(string: "https://status.imgix.com/")! }
    override var statusPageID: String { return "032k0f0j3bsz" }
}
