//
//  Mapbox.swift
//  stts
//

import Foundation

class Mapbox: StatusPageService {
    override var url: URL { return URL(string: "http://status.mapbox.com")! }
    override var statusPageID: String { return "l363gv8nm9gc" }
}
