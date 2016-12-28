//
//  Mixpanel.swift
//  stts
//

import Foundation

class Mixpanel: StatusPageService {
    override var url: URL { return URL(string: "https://status.mixpanel.com")! }
    override var statusPageID: String { return "x4m91ldrf511" }
}
