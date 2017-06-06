//
//  Trello.swift
//  stts
//

import Foundation

class Trello: StatusPageService {
    override var url: URL { return URL(string: "https://www.trellostatus.com")! }
    override var statusPageID: String { return "h5frqhb041yq" }
}
