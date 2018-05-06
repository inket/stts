//
//  Firebase.swift
//  stts
//

import Foundation

typealias FirebaseService = BaseFirebaseService & RequiredServiceProperties & RequiredFirebaseProperties

protocol RequiredFirebaseProperties: GoogleStatusDashboardStoreService {
    var name: String { get }
    var dashboardName: String { get }
}

extension RequiredFirebaseProperties {
    var dashboardName: String {
        let prefix = "Firebase "
        guard let prefixRange = name.range(of: prefix), prefixRange.lowerBound.encodedOffset == 0 else { return name }

        return name.replacingCharacters(in: prefixRange, with: "")
    }
}

private let firebaseDashboardURL = URL(string: "https://status.firebase.google.com")!

class BaseFirebaseService: BaseService {
    private static var store = GoogleStatusDashboardStore(url: firebaseDashboardURL, generalType: Firebase.self)

    let url = firebaseDashboardURL

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? FirebaseService else { fatalError("BaseFirebaseService should not be used directly.") }

        BaseFirebaseService.store.loadStatus { [weak realSelf] in
            guard let selfie = realSelf else { return }

            let (status, message) = BaseFirebaseService.store.status(for: selfie)
            selfie.status = status
            selfie.message = message

            callback(selfie)
        }
    }
}
