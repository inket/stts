//
//  Azure.swift
//  stts
//

import Foundation

typealias Azure = BaseAzure & RequiredServiceProperties & AzureStoreService

class BaseAzure: BaseService {
    private static var store = AzureStore()

    let url = URL(string: "https://status.azure.com/en-us/status")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? Azure else { fatalError("BaseAzure should not be used directly.") }

        BaseAzure.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            strongSelf.statusDescription = BaseAzure.store.status(for: strongSelf)
            callback(strongSelf)
        }
    }
}
