//
//  WalletSecretDataSource.swift
//  xWallet
//
//  Created by Xueliang Zhu on 2/4/26.
//

import Foundation

struct WalletSecretDataSource {
    private struct SecretPayload: Codable {
        let type: String
        let value: String
        let chain: String?
        let subtype: String?
    }

    private let securityStore: SecurityStore

    init(securityStore: SecurityStore) {
        self.securityStore = securityStore
    }

    func saveSecret(_ source: WalletSource, for id: UUID) throws {
        let key: String
        let payload: SecretPayload
        switch source {
        case .mnemonic(let mnemonic):
            key = mnemonicAccount(for: id)
            payload = SecretPayload(type: "mnemonic", value: mnemonic, chain: nil, subtype: nil)
        case .privateKey(let pkData, let accountType):
            key = privateKeyAccount(for: id)
            payload = SecretPayload(
                type: "privateKey",
                value: pkData.base64EncodedString(),
                chain: accountType.chainType.rawValue,
                subtype: accountType.starknetAccountType?.rawValue
            )
        }
        let data = try JSONEncoder().encode(payload)
        try securityStore.saveData(data, account: key, policy: .highSecurity)
    }

    func loadSecret(for id: UUID, reason: String) throws -> WalletSource {
        do {
            let data = try securityStore.loadData(account: mnemonicAccount(for: id), reason: reason, policy: .highSecurity)
            return try decodeSecret(from: data)
        } catch KeychainError.itemNotFound {
            let data = try securityStore.loadData(account: privateKeyAccount(for: id), reason: reason, policy: .highSecurity)
            return try decodeSecret(from: data)
        }
    }

    func deleteSecret(for id: UUID) throws {
        try deleteAll(for: id)
    }

    func deleteAll(for id: UUID) throws {
        do { try securityStore.delete(account: privateKeyAccount(for: id)) }
        catch KeychainError.itemNotFound { }

        do { try securityStore.delete(account: mnemonicAccount(for: id)) }
        catch KeychainError.itemNotFound { }
    }
    
    func deleteAll() throws {
        try securityStore.deleteAll()
    }
}

private extension WalletSecretDataSource {
    func decodeSecret(from data: Data) throws -> WalletSource {
        if let payload = try? JSONDecoder().decode(SecretPayload.self, from: data) {
            return try decodeSecret(from: payload)
        }

        let legacyPayload = try JSONDecoder().decode([String: String].self, from: data)
        let payload = SecretPayload(
            type: legacyPayload["type"] ?? "",
            value: legacyPayload["value"] ?? "",
            chain: legacyPayload["chain"],
            subtype: legacyPayload["subtype"]
        )
        return try decodeSecret(from: payload)
    }

    private func decodeSecret(from payload: SecretPayload) throws -> WalletSource { 
        switch payload.type {
        case "mnemonic":
            return .mnemonic(payload.value)
        case "privateKey":
            guard let pkData = Data(base64Encoded: payload.value),
                  let chain = payload.chain,
                  let accountType = AccountType(rawValue: chain, subtype: payload.subtype) else {
                throw WalletError.decodingFailed
            }
            return .privateKey(pkData, accountType)
        default:
            throw WalletError.decodingFailed
        }
    }

    func privateKeyAccount(for id: UUID) -> String {
        "wallet_\(id.uuidString)"
    }

    func mnemonicAccount(for id: UUID) -> String {
        "wallet_mnemonic_\(id.uuidString)"
    }
}
