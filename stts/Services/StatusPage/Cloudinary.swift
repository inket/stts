//
//  Cloudinary.swift
//  stts
//

import Foundation

class Cloudinary: StatusPageService {
    override var url: URL { return URL(string: "http://status.cloudinary.com")! }
    override var statusPageID: String { return "d8rszhl2bj7r" }
}
