//
//  AzureDevOpsDevOps.swift
//  stts
//

import Foundation

typealias AzureDevOps = BaseAzureDevOps & RequiredServiceProperties & AzureDevOpsStoreService

class BaseAzureDevOps: BaseIndependentService {
    private static let store = AzureDevOpsStore()

    let url = URL(string: "https://status.dev.azure.com")!

    override func updateStatus() async throws {
        guard let realSelf = self as? AzureDevOps else {
            fatalError("BaseAzureDevOps should not be used directly.")
        }

        statusDescription = try await BaseAzureDevOps.store.updatedStatus(for: realSelf)
    }
}
