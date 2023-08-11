//
//  Salesforce.swift
//  Salesforce
//

import Foundation

typealias Salesforce = BaseSalesforce & RequiredServiceProperties & SalesforceStoreService & InheritsSalesforceCategory
typealias BaseSalesforceCategory = BaseSalesforce & InheritsSalesforceCategory

protocol InheritsSalesforceCategory {
    static var store: SalesforceStore { get }
}

extension InheritsSalesforceCategory {
    var store: SalesforceStore {
        Self.store
    }
}

class BaseSalesforce: BaseIndependentService {
    override func updateStatus() async throws {
        guard let realSelf = self as? Salesforce else {
            fatalError("BaseSalesforce should not be used directly.")
        }

        statusDescription = try await realSelf.store.updatedStatus(for: realSelf)
    }
}
