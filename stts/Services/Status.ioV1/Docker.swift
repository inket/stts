//
//  Docker.swift
//  stts
//

import Foundation

class Docker: StatusioV1Service {
    override var url: URL { return URL(string: "https://status.docker.com/")! }
    override var statusPageID: String { return "533c6539221ae15e3f000031" }
}
