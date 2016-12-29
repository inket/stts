//
//  MediaTemple.swift
//  stts
//

import Foundation

class MediaTemple: StatusPageService {
    override var name: String { return "Media Temple" }
    override var url: URL { return URL(string: "http://status.mediatemple.net")! }
    override var statusPageID: String { return "sk0wbwpc3xqq" }
}
