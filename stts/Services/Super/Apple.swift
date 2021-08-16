//
//  Apple.swift
//  stts
//

import Foundation

typealias Apple = BaseApple & RequiredServiceProperties & AppleStoreService

class BaseApple: BaseService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js"
    )

    let url = URL(string: "https://www.apple.com/support/systemstatus/")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? Apple else { fatalError("BaseApple should not be used directly.") }

        BaseApple.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            let (status, message) = BaseApple.store.status(for: strongSelf)
            strongSelf.status = status
            strongSelf.message = message

            callback(strongSelf)
        }
    }
}
