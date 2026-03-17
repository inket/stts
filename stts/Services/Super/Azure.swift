//
//  Azure.swift
//  stts
//

import Foundation

typealias Azure = BaseAzure & RequiredServiceProperties & AzureStoreService

class BaseAzure: BaseIndependentService {
    private static var store = AzureStore()

    let url = URL(string: "https://status.azure.com/en-us/status")!

    override func updateStatus() async throws {
        guard let realSelf = self as? Azure else {
            fatalError("BaseAzure should not be used directly.")
        }

        statusDescription = try await BaseAzure.store.updatedStatus(for: realSelf)
    }
}
