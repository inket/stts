//
//  GoogleCloudPlatformAll.swift
//  stts
//

import Foundation

class GoogleCloudPlatformAll: GoogleCloudPlatform, ServiceCategory {
    let categoryName = "Google Cloud Platform"
    let subServiceSuperclass: AnyObject.Type = BaseGoogleCloudPlatform.self

    let name = "Google Cloud Platform (All)"
}
