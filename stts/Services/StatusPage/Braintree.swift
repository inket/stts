//
//  Braintree.swift
//  stts
//

import Cocoa

class Braintree: StatusPageService {
    override var name: String { return "Braintree" }
    override var url: URL { return URL(string: "https://status.braintreepayments.com")! }
    override var statusPageID: String { return "03tltrdl3qkv" }
}
