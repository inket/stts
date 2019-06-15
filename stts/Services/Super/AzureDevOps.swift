//
//  AzureDevOpsDevOps.swift
//  stts
//

import Foundation

typealias AzureDevOps = BaseAzureDevOps & RequiredServiceProperties & AzureDevOpsStoreService

class BaseAzureDevOps: BaseService {
    private static var store = AzureDevOpsStore()

    let url = URL(string: "https://status.dev.azure.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? AzureDevOps else { fatalError("BaseAzureDevOps should not be used directly.") }

        BaseAzureDevOps.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            let (status, message) = BaseAzureDevOps.store.status(for: strongSelf)
            strongSelf.status = status
            strongSelf.message = message

            callback(strongSelf)
        }
    }
}
