//
//  Atlassian.swift
//  stts
//

import Foundation

class Atlassian: StatusPageService {
    override var url: URL { return URL(string: "http://status.atlassian.com")! }
    override var statusPageID: String { return "x67gp49yvrzv" }
}
