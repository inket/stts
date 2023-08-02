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

class BaseSalesforce: BaseService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? Salesforce else {
            fatalError("BaseSalesforce should not be used directly.")
        }

        realSelf.store.loadStatus { [weak realSelf] in
            guard let strongSelf = realSelf else { return }

            strongSelf.statusDescription = strongSelf.store.status(for: strongSelf)
            callback(strongSelf)
        }
    }
}
