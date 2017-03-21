//
//  Codacy.swift
//  stts
//

import Cocoa

class Codacy: ExanaService {
    override var url: URL { return URL(string: "https://status.codacy.com")! }
    override var serviceID: String { return "EXID-SRVC-9931x913std5p9x3" }
}
