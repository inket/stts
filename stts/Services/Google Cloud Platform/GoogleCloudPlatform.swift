//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

class GoogleCloudPlatform: Service {
    override var name: String { return "Google Cloud Platform (All)" }
    override var url: URL { return URL(string: "https://status.cloud.google.com")! }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        GoogleCloudPlatformStatusStore.loadStatus(for: self) { [weak self] in
            guard let selfie = self else { return }

            let (status, message) = GoogleCloudPlatformStatusStore.status(for: selfie)
            self?.status = status
            self?.message = message

            callback(selfie)
        }
    }
}
