//
//  AppleDeveloper.swift
//  stts
//

import Foundation

typealias AppleDeveloper = BaseAppleDeveloper & RequiredServiceProperties & AppleStoreService

class BaseAppleDeveloper: BaseService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js"
    )

    let url = URL(string: "https://developer.apple.com/system-status/")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? AppleDeveloper else {
            fatalError("BaseAppleDeveloper should not be used directly.")
        }

        BaseAppleDeveloper.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            let (status, message) = BaseAppleDeveloper.store.status(for: strongSelf)
            strongSelf.status = status
            strongSelf.message = message

            callback(strongSelf)
        }
    }
}
