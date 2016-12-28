//
//  Twilio.swift
//  stts
//

import Foundation

class Twilio: StatusPageService {
    override var url: URL { return URL(string: "https://status.twilio.com")! }
    override var statusPageID: String { return "gpkpyklzq55q" }
}
