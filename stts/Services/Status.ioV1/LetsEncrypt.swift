//
//  LetsEncrypt.swift
//  stts
//

import Foundation

class LetsEncrypt: StatusioV1Service {
    let name = "Let's Encrypt"
    let url = URL(string: "https://letsencrypt.status.io")!
    let statusPageID = "55957a99e800baa4470002da"
}
