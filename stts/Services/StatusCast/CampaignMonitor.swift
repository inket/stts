//
//  CampaignMonitor.swift
//  stts
//

import Foundation

class CampaignMonitor: StatusCastService {
    let name = "Campaign Monitor"
    let hasCurrentStatus = true
    let url = URL(string: "https://status.campaignmonitor.com")!
}
