//
//  AzureAll.swift
//  stts
//

import Foundation

class AzureAll: Azure, ServiceCategory {
    let categoryName = "Azure"
    let subServiceSuperclass: AnyObject.Type = BaseAzure.self

    let name = "Azure (All Regions)"
    let zoneIdentifier = "*"
}
