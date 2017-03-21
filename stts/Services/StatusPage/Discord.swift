//
//  Discord.swift
//  stts
//

import Foundation

class Discord: StatusPageService {
    override var url: URL { return URL(string: "https://status.discordapp.com")! }
    override var statusPageID: String { return "srhpyqt94yxb" }
}
