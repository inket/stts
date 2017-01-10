//
//  SendGrid.swift
//  stts
//

import Foundation

class SendGrid: StatusPageService {
    override var url: URL { return URL(string: "http://status.sendgrid.com")! }
    override var statusPageID: String { return "3tgl2vf85cht" }
}
