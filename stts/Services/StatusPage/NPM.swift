//
//  NPM.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class NPM: StatusPageService {
    override var name: String { return "NPM" }
    override var url: URL { return URL(string: "http://status.npmjs.org")! }
    override var statusPageID: String { return "wyvgptkd90hm" }
}
