//
//  CircleCI.swift
//  stts
//
//  Created by inket on 19/8/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class CircleCI: StatusPageService {
    override var name: String { return "CircleCI" }
    override var url: URL { return URL(string: "https://status.circleci.com/")! }
    override var statusPageID: String { return "6w4r0ttlx5ft" }
}
