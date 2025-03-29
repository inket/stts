//
//  DigitalOcean.swift
//  stts
//

import Foundation

final class DigitalOcean: StatusPageService {
    let statusPageID = "w4cz49tckxhp"
    let url = URL(string: "https://status.digitalocean.com")!
}
