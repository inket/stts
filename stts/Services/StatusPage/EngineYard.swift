//
//  EngineYard.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class EngineYard: StatusPageService {
    override var name: String { return "Engine Yard" }
    override var url: URL { return URL(string: "https://engineyard.statuspage.io")! }
    override var statusPageID: String { return "76sphw1bc50q" }
}
