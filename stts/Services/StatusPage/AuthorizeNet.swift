//
//  AuthorizeNet.swift
//  stts
//

import Foundation

class AuthorizeNet: StatusPageService {
    override var name: String { return "Authorize.Net" }
    override var url: URL { return URL(string: "https://status.authorize.net")! }
    override var statusPageID: String { return "py5v2nkvrdpm" }
}
