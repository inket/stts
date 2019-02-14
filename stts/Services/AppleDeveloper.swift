//
//  AppleDeveloper.swift
//  stts
//

import Foundation

class AppleDeveloper: Apple {
    override var name: String { return "Apple Developer" }

    override var url: URL {
        return URL(string: "https://developer.apple.com/system-status/")!
    }

    override var dataURL: URL {
        return URL(string: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js")!
    }
}
