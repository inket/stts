//
//  Firebase.swift
//  stts
//

import Foundation

typealias FirebaseService = BaseFirebaseService & RequiredServiceProperties & RequiredFirebaseProperties

protocol RequiredFirebaseProperties: FirebaseStatusDashboardStoreService {
    var name: String { get }
    var dashboardName: String { get }
}

extension RequiredFirebaseProperties {
    var dashboardName: String {
        let prefix = "Firebase "

        guard let prefixRange = name.range(of: prefix), prefixRange.lowerBound.utf16Offset(in: name) == 0 else {
            return name
        }

        return name.replacingCharacters(in: prefixRange, with: "")
    }
}

private let firebaseDashboardURL = URL(string: "https://status.firebase.google.com")!

class BaseFirebaseService: BaseIndependentService {
    private static var store = FirebaseStatusDashboardStore(url: firebaseDashboardURL)

    let url = firebaseDashboardURL

    override func updateStatus() async throws {
        guard let realSelf = self as? FirebaseService else {
            fatalError("BaseFirebaseService should not be used directly.")
        }

        statusDescription = try await BaseFirebaseService.store.updatedStatus(for: realSelf)
    }
}
