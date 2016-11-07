//
//  RubyGems.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class RubyGems: StatusPageService {
    override var name: String { return "RubyGems" }
    override var url: URL { return URL(string: "https://status.rubygems.org")! }
    override var statusPageID: String { return "pclby00q90vc" }
}
