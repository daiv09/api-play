//
//  KeychainHelper.swift
//  api-play
//
//  A minimal wrapper around the Security framework to safely store and
//  retrieve sensitive API keys / passwords associated with env-var IDs.
//

import Foundation
import Security

struct KeychainHelper {

    private static let service = "com.api-play.envvars"
    // The access group must use the AppIdentifierPrefix
    private static let accessGroup = "teamid.com.api-play.shared"

    // MARK: - Write

    @discardableResult
    static func write(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Attempt to update first; if not found, add.
        let updateQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
            // kSecAttrAccessGroup: accessGroup // Only uncomment when real Team ID is known and configured
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = updateQuery
            addQuery[kSecValueData] = data
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return updateStatus == errSecSuccess
    }

    // MARK: - Read

    static func read(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
            // kSecAttrAccessGroup: accessGroup
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
            // kSecAttrAccessGroup: accessGroup
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
