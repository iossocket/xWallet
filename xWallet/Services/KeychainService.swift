//
//  KeychainService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/1/26.
//

import Foundation
import Security
import Dependencies

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

struct KeychainClient {
    var saveData: @Sendable (Data, String) throws -> Void
    var loadData: @Sendable (String) throws -> Data
    var delete: @Sendable (String) throws -> Void
}

final class KeychainService {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "xWallet") {
        self.service = service
    }

    func saveData(_ data: Data, account: String) throws {
        // delete existing
        try? delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func loadData(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
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
}

extension KeychainClient: DependencyKey {
    static var liveValue: KeychainClient {
        let service = KeychainService()
        return KeychainClient(
            saveData: { data, account in try service.saveData(data, account: account) },
            loadData: { account in try service.loadData(account: account) },
            delete: { account in try service.delete(account: account) }
        )
    }

    static var testValue: KeychainClient {
        KeychainClient(
            saveData: { _, _ in },
            loadData: { _ in throw KeychainError.itemNotFound },
            delete: { _ in }
        )
    }

    static var previewValue: KeychainClient {
        KeychainClient(
            saveData: { _, _ in },
            loadData: { _ in throw KeychainError.itemNotFound },
            delete: { _ in }
        )
    }
}


extension DependencyValues {
    var keychain: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}

