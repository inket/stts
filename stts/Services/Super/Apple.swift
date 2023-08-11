//
//  Apple.swift
//  stts
//

import Foundation

typealias Apple = BaseApple & RequiredServiceProperties & AppleStoreService

class BaseApple: BaseIndependentService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js"
    )

    let url = URL(string: "https://www.apple.com/support/systemstatus/")!

    override func updateStatus() async throws {
        guard let realSelf = self as? Apple else {
            fatalError("BaseApple should not be used directly.")
        }

        statusDescription = try await BaseApple.store.updatedStatus(for: realSelf)
    }
}
