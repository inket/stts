//
//  JiraServiceManagement.swift
//  stts
//

import Foundation

final class JiraServiceManagement: StatusPageService {
    let name = "Jira Service Management"
    let url = URL(string: "https://jira-service-management.status.atlassian.com")!
    let statusPageID = "pv54g7ltsc24"
}
