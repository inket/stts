//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

typealias GoogleCloudPlatform = BaseGoogleCloudPlatform & RequiredServiceProperties

class BaseGoogleCloudPlatform: BaseService {
    let url = URL(string: "https://status.cloud.google.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? GoogleCloudPlatform else { fatalError("BaseGoogleCloudPlatform should not be used directly.") }

        GoogleCloudPlatformStatusStore.loadStatus(for: self) { [weak realSelf] in
            guard let selfie = realSelf else { return }

            let (status, message) = GoogleCloudPlatformStatusStore.status(for: selfie)
            selfie.status = status
            selfie.message = message

            callback(selfie)
        }
    }
}
