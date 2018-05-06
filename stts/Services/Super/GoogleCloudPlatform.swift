//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

typealias GoogleCloudPlatform = BaseGoogleCloudPlatform & RequiredServiceProperties & GoogleStatusDashboardStoreService

private let gcpDashboardURL = URL(string: "https://status.cloud.google.com")!

class BaseGoogleCloudPlatform: BaseService {
    private static var store = GoogleStatusDashboardStore(url: gcpDashboardURL, generalType: GoogleCloudPlatformAll.self)

    let url = gcpDashboardURL

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? GoogleCloudPlatform else { fatalError("BaseGoogleCloudPlatform should not be used directly.") }

        BaseGoogleCloudPlatform.store.loadStatus { [weak realSelf] in
            guard let selfie = realSelf else { return }

            let (status, message) = BaseGoogleCloudPlatform.store.status(for: selfie)
            selfie.status = status
            selfie.message = message

            callback(selfie)
        }
    }
}
