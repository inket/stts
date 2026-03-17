//
//  AppleDeveloper.swift
//  stts
//

import Foundation

typealias AppleDeveloper = BaseAppleDeveloper & RequiredServiceProperties & AppleStoreService

class BaseAppleDeveloper: BaseIndependentService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js"
    )

    let url = URL(string: "https://developer.apple.com/system-status/")!

    override func updateStatus() async throws {
        guard let realSelf = self as? AppleDeveloper else {
            fatalError("BaseAppleDeveloper should not be used directly.")
        }

        statusDescription = try await BaseAppleDeveloper.store.updatedStatus(for: realSelf)
    }
}
