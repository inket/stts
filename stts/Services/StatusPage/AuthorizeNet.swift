//
//  AuthorizeNet.swift
//  stts
//

import Foundation

class AuthorizeNet: StatusPageService {
    override var url: URL { return URL(string: "http://status.authorize.net")! }
    override var statusPageID: String { return "py5v2nkvrdpm" }
}
