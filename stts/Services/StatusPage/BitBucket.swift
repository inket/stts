//
//  BitBucket.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class BitBucket: StatusPageService {
    override var name: String { return "BitBucket" }
    override var url: URL { return URL(string: "https://status.bitbucket.org")! }
    override var statusPageID: String { return "bqlf8qjztdtr" }
}
