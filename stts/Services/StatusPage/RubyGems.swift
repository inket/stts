//
//  RubyGems.swift
//  stts
//

import Foundation

final class RubyGems: StatusPageService {
    let url = URL(string: "https://status.rubygems.org")!
    let statusPageID = "pclby00q90vc"
}
