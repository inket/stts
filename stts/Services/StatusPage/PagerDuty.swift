//
//  PagerDuty.swift
//  stts
//

import Foundation

class PagerDuty: StatusPageService {
    override var url: URL { return URL(string: "https://status.pagerduty.com")! }
    override var statusPageID: String { return "33yy6hwxnwr3" }
}
