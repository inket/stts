//
//  DNSimple.swift
//  stts
//

import Foundation

class DNSimple: StatusPageService {
    override var url: URL { return URL(string: "https://status.dnsimple.com")! }
    override var statusPageID: String { return "tjym90yyv2zt" }
}
