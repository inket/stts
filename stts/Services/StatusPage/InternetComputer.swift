//
//  InternetComputer.swift
//  stts
//

import Foundation

final class InternetComputer: StatusPageService {
    let name = "Internet Computer"
    let url = URL(string: "https://status.internetcomputer.org")!
    let statusPageID = "kc2llmsd16bk"
}
