//
//  Fastly.swift
//  stts
//

import Foundation

class Fastly: StatusPageService {
    let url = URL(string: "http://status.fastly.com")!
    let statusPageID = "889dh1w1xtt0"
}
