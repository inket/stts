//
//  Datadog.swift
//  stts
//

import Foundation

final class DatadogEU: StatusPageService {
    let name = "Datadog (EU)"
    let url = URL(string: "https://status.datadoghq.eu")!
    let statusPageID = "5by3sysm209d"
}
