//
//  GitLab.swift
//  stts
//

import Foundation

class GitLab: StatusioV1Service {
    let url = URL(string: "https://status.gitlab.com")!
    let statusPageID = "5b36dc6502d06804c08349f7"
}
