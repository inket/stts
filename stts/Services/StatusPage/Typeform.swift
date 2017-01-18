//
//  Typeform.swift
//  stts
//

import Foundation

class Typeform: StatusPageService {
    override var url: URL { return URL(string: "http://status.typeform.com")! }
    override var statusPageID: String { return "fv5fyw3p7k8n" }
}
