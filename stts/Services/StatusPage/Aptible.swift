//
//  Aptible.swift
//  stts
//

import Foundation

class Aptible: StatusPageService {
    override var url: URL { return URL(string: "http://status.aptible.com/")! }
    override var statusPageID: String { return "fmwgqnbnbc4r" }
}
