//
//  SendGrid.swift
//  stts
//

import Foundation

final class SendGrid: StatusPageService {
    let url = URL(string: "https://status.sendgrid.com")!
    let statusPageID = "3tgl2vf85cht"
}
