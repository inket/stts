//
//  Pusher.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class Pusher: StatusPageService {
    override var name: String { return "Pusher" }
    override var url: URL { return URL(string: "https://status.pusher.com/")! }
    override var statusPageID: String { return "p6t5x7tdq8yq" }
}
