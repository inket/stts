//
//  AzureDevOpsAll.swift
//  stts
//

import Foundation

class AzureDevOpsAll: AzureDevOps, ServiceCategory {
    let categoryName = "Azure DevOps"
    let subServiceSuperclass: AnyObject.Type = BaseAzureDevOps.self

    let name = "Azure DevOps (All)"
    let serviceName = "*"
}
