//
//  KeychainService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/1/26.
//

import Foundation
import Security
import LocalAuthentication

enum KeychainError: Error, LocalizedError, Equatable {
    case unexpectedStatus(OSStatus)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): return "Keychain error: \(status)"
        case .itemNotFound: return "Keychain item not found"
        }
    }
}

enum SecretPolicy {
    case appUnlock        // userPresence
    case highSecurity     // biometryCurrentSet
}

protocol SecurityStore {
    func saveData(_ data: Data, account: String, policy: SecretPolicy) throws
    func loadData(account: String, reason: String, policy: SecretPolicy) throws -> Data
    func delete(account: String) throws
    func deleteAll() throws
}


struct KeychainService: SecurityStore {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "xWallet") {
        self.service = service
    }

    func saveData(_ data: Data, account: String, policy: SecretPolicy = .highSecurity) throws {
        // delete existing
        try? delete(account: account)
        
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func loadData(account: String, reason: String, policy: SecretPolicy = .highSecurity) throws -> Data {
        let context = LAContext()
        context.localizedReason = reason
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }

        guard let data = item as? Data else { throw KeychainError.unexpectedStatus(errSecInternalError) }
        return data
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
