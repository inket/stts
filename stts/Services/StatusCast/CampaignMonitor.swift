//
//  CampaignMonitor.swift
//  stts
//

import Foundation

final class CampaignMonitor: StatusCastService {
    let name = "Campaign Monitor"
    let hasCurrentStatus = true
    let url = URL(string: "https://status.campaignmonitor.com")!
}
