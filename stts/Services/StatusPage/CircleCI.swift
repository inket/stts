//
//  CircleCI.swift
//  stts
//

import Foundation

final class CircleCI: StatusPageService {
    let url = URL(string: "https://status.circleci.com")!
    let statusPageID = "6w4r0ttlx5ft"
}
