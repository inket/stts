//
//  CloudFlare.swift
//  stts
//
//  Created by inket on 7/11/16.
//  Copyright © 2016 inket. All rights reserved.
//

import Cocoa

class CloudFlare: StatusPageService {
    override var name: String { return "CloudFlare" }
    override var url: URL { return URL(string: "https://www.cloudflarestatus.com")! }
    override var statusPageID: String { return "yh6f0r4529hb" }
}
