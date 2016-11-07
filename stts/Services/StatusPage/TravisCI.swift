//
//  TravisCI.swift
//  stts
//
//  Created by inket on 17/8/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class TravisCI: StatusPageService {
    override var name: String { return "TravisCI" }
    override var url: URL { return URL(string: "https://www.traviscistatus.com/")! }
    override var statusPageID: String { return "pnpcptp8xh9k" }
}
