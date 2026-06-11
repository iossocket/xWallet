//
//  KeychainStore.swift
//  xWallet
//
//  Created by Xueliang Zhu on 8/6/26.
//

import Foundation
import Security
import LocalAuthentication
import ComposableArchitecture

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

private enum KeychainServiceName: DependencyKey {
    static let liveValue = Bundle.main.bundleIdentifier ?? "xWallet"
}

extension DependencyValues {
    var keychainServiceName: String {
        get { self[KeychainServiceName.self] }
        set { self[KeychainServiceName.self] = newValue }
    }
}

@DependencyClient
struct KeychainStore {
    var saveData: (_ data: Data, _ account: String, _ policy: SecretPolicy) throws -> Void
    var loadData: (_ account: String, _ reason: String, _ policy: SecretPolicy) throws -> Data
    var delete: (_ account: String) throws -> Void
    var deleteAll: () throws -> Void
}

private func keychainDelete(account: String, service: String) throws {
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

extension KeychainStore: DependencyKey {
    static var liveValue: Self {
        KeychainStore { data, account, policy in
            @Dependency(\.keychainServiceName) var keychainServiceName

            try? keychainDelete(account: account, service: keychainServiceName)

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
                kSecAttrService as String: keychainServiceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessControl as String: accessControl
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        } loadData: { account, reason, policy in
            @Dependency(\.keychainServiceName) var keychainServiceName
            let context = LAContext()
            context.localizedReason = reason
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainServiceName,
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
        } delete: { account in
            @Dependency(\.keychainServiceName) var keychainServiceName
            try keychainDelete(account: account, service: keychainServiceName)
        } deleteAll: {
            @Dependency(\.keychainServiceName) var keychainServiceName
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainServiceName,
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }
}

extension DependencyValues {
    var keychainStore: KeychainStore {
        get { self[KeychainStore.self] }
        set { self[KeychainStore.self] = newValue }
    }
}
