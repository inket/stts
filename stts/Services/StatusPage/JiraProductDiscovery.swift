//
//  JiraProductDiscovery.swift
//  stts
//

import Foundation

final class JiraProductDiscovery: StatusPageService {
    let name = "Jira Product Discovery"
    let url = URL(string: "https://jira-product-discovery.status.atlassian.com")!
    let statusPageID = "qmzzdxyvmbmk"
}
