//
//  Pingdom.swift
//  stts
//

import Foundation

final class Pingdom: SorryService {
    let url = URL(string: "https://status.pingdom.com")!
    let pageID = "2273"
}
