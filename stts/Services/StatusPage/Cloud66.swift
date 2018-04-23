//
//  Cloud66.swift
//  stts
//

import Foundation

class Cloud66: StatusPageService {
    override var url: URL { return URL(string: "https://status.cloud66.com")! }
    override var statusPageID: String { return "55a770a50a54eb8c710005a9" }
}
