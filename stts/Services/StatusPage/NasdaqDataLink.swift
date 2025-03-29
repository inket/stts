//
//  NasdaqDataLink.swift
//  stts
//

import Foundation

final class NasdaqDataLink: StatusPageService {
    let name = "Nasdaq Data Link"
    let url = URL(string: "https://status.data.nasdaq.com")!
    let statusPageID = "dyfxchz1hcb1"
}
