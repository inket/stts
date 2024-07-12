//
//  Pingdom.swift
//  stts
//

import Foundation

class Pingdom: SorryService {
    let url = URL(string: "https://status.pingdom.com")!
    let pageID = "9c53640d" // Page ID was found on page back in 2018, and is now nowhere to be found
}
