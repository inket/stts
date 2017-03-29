//
//  Auth0.swift
//  stts
//

import Foundation

class Auth0: StatusPageService {
    override var url: URL { return URL(string: "https://status.auth0.com")! }
    override var statusPageID: String { return "8q60stg1rk7l" }
}
