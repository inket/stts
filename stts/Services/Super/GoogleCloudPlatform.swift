//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

typealias GoogleCloudPlatform = BaseGoogleCloudPlatform & RequiredServiceProperties & GoogleStatusDashboardStoreService

private let gcpDashboardURL = URL(string: "https://status.cloud.google.com")!

class BaseGoogleCloudPlatform: BaseService {
    private static var store = GoogleStatusDashboardStore(url: gcpDashboardURL)

    let url = gcpDashboardURL

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? GoogleCloudPlatform else {
            fatalError("BaseGoogleCloudPlatform should not be used directly.")
        }

        BaseGoogleCloudPlatform.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            let (status, message) = BaseGoogleCloudPlatform.store.status(for: strongSelf)
            strongSelf.status = status
            strongSelf.message = message

            callback(strongSelf)
        }
    }
}
