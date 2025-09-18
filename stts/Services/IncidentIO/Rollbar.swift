//
//  Rollbar.swift
//  stts
//

import Foundation

final class Rollbar: IncidentIOService {
    let url = URL(string: "https://status.rollbar.com")!
}
