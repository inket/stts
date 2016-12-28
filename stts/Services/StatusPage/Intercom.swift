//
//  Intercom.swift
//  stts
//

import Foundation

class Intercom: StatusPageService {
    override var url: URL { return URL(string: "https://status.intercom.com")! }
    override var statusPageID: String { return "1m1j8k4rtldg" }
}
