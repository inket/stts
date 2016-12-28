//
//  Braintree.swift
//  stts
//

import Foundation

class Braintree: StatusPageService {
    override var url: URL { return URL(string: "https://status.braintreepayments.com")! }
    override var statusPageID: String { return "03tltrdl3qkv" }
}
