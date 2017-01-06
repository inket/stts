//
//  Packet.swift
//  stts
//
//  Created by D on 1/6/17.
//  Copyright © 2017 inket. All rights reserved.
//

import Foundation

class Packet: StatusPageService {
    override var name: String { return "Packet" }
    override var url: URL { return URL(string: "http://packet.statuspage.io")! }
    override var statusPageID: String { return "39f8vhy6rw5d" }
}
