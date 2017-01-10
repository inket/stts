//
//  EngineYard.swift
//  stts
//

import Foundation

class EngineYard: StatusPageService {
    override var name: String { return "Engine Yard" }
    override var url: URL { return URL(string: "http://status.engineyard.com")! }
    override var statusPageID: String { return "76sphw1bc50q" }
}
