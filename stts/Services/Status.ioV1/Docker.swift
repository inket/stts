//
//  Docker.swift
//  stts
//

import Foundation

class Docker: StatusioV1Service {
    let url = URL(string: "https://status.docker.com/")!
    let statusPageID = "533c6539221ae15e3f000031"
}
