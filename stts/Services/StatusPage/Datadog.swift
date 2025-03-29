//
//  Datadog.swift
//  stts
//

import Foundation

final class Datadog: StatusPageService {
    let url = URL(string: "https://status.datadoghq.com")!
    let statusPageID = "1k6wzpspjf99"
}
