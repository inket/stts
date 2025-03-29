//
//  Scaleway.swift
//  stts
//

import Foundation

final class Scaleway: StatusPageService {
    let url = URL(string: "https://status.scaleway.com")!
    let statusPageID = "s2kbtscly3pj"
}
