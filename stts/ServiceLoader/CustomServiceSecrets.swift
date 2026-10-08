//
//  CustomServiceSecrets.swift
//  stts
//

import Foundation
import Security

/// Where secret header values live, keyed by service and header name. A protocol so tests can
/// swap the Keychain for a dictionary.
protocol CustomServiceSecrets: AnyObject {
    func value(serviceID: UUID, headerName: String) -> String?
    func setValue(_ value: String, serviceID: UUID, headerName: String)
    func removeValue(serviceID: UUID, headerName: String)
}

extension CustomServiceSecrets {
    /// Header names are case-insensitive, so the key is too.
    static func account(serviceID: UUID, headerName: String) -> String {
        "\(serviceID.uuidString)/\(headerName.lowercased())"
    }
}

/// Generic password items in the login keychain, one per secret header.
final class KeychainCustomServiceSecrets: CustomServiceSecrets {
    private static let service = "jp.mahdi.stts.custom-headers"

    func value(serviceID: UUID, headerName: String) -> String? {
        var query = baseQuery(serviceID: serviceID, headerName: headerName)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setValue(_ value: String, serviceID: UUID, headerName: String) {
        let query = baseQuery(serviceID: serviceID, headerName: headerName)
        let data = Data(value.utf8)

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "stts custom service header"
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if addStatus != errSecSuccess {
                debugPrint("Couldn't save a custom service secret: \(addStatus)")
            }
        } else if status != errSecSuccess {
            debugPrint("Couldn't update a custom service secret: \(status)")
        }
    }

    func removeValue(serviceID: UUID, headerName: String) {
        SecItemDelete(baseQuery(serviceID: serviceID, headerName: headerName) as CFDictionary)
    }

    private func baseQuery(serviceID: UUID, headerName: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account(serviceID: serviceID, headerName: headerName)
        ]
    }
}

/// For tests, and anywhere the Keychain shouldn't be touched.
final class InMemoryCustomServiceSecrets: CustomServiceSecrets {
    private(set) var values: [String: String] = [:]

    func value(serviceID: UUID, headerName: String) -> String? {
        values[Self.account(serviceID: serviceID, headerName: headerName)]
    }

    func setValue(_ value: String, serviceID: UUID, headerName: String) {
        values[Self.account(serviceID: serviceID, headerName: headerName)] = value
    }

    func removeValue(serviceID: UUID, headerName: String) {
        values[Self.account(serviceID: serviceID, headerName: headerName)] = nil
    }
}
