//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

typealias GoogleCloudPlatform = BaseGoogleCloudPlatform & RequiredServiceProperties & GoogleStatusDashboardStoreService

private let gcpDashboardURL = URL(string: "https://status.cloud.google.com")!

class BaseGoogleCloudPlatform: BaseIndependentService {
    private static var store = GoogleStatusDashboardStore(url: gcpDashboardURL)

    let url = gcpDashboardURL

    override func updateStatus() async throws {
        guard let realSelf = self as? GoogleCloudPlatform else {
            fatalError("BaseGoogleCloudPlatform should not be used directly.")
        }

        statusDescription = try await BaseGoogleCloudPlatform.store.updatedStatus(for: realSelf)
    }
}
