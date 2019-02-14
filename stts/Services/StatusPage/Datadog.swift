//
//  Datadog.swift
//  stts
//

import Foundation

class Datadog: StatusPageService {
    let url = URL(string: "https://status.datadoghq.com")!
    let statusPageID = "1k6wzpspjf99"
}
