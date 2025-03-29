//
//  Opsgenie.swift
//  stts
//

import Foundation

final class Opsgenie: StatusPageService {
    let url = URL(string: "https://opsgenie.status.atlassian.com")!
    let statusPageID = "t05vdsszxwtq"
}
