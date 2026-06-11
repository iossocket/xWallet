//
//  WalletSecretRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 2/4/26.
//

import Foundation
import ComposableArchitecture

@DependencyClient
struct WalletSecretRepository {
    var saveSecret: (_ source: WalletSource, _ id: UUID) throws -> Void
    var loadSecret: (_ id: UUID, _ reason: String) throws -> WalletSource
    var deleteSecret: (_ id: UUID) throws -> Void
    var deleteAll: () throws -> Void
}

extension WalletSecretRepository: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.keychainStore) var keychainStore
        return WalletSecretRepository(
            saveSecret: { source, id in
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
                try keychainStore.saveData(data: data, account: key, policy: .highSecurity)
            },
            loadSecret: { id, reason in
                do {
                    let data = try keychainStore.loadData(account: mnemonicAccount(for: id), reason: reason, policy: .highSecurity)
                    return try decodeSecret(from: data)
                } catch KeychainError.itemNotFound {
                    let data = try keychainStore.loadData(account: privateKeyAccount(for: id), reason: reason, policy: .highSecurity)
                    return try decodeSecret(from: data)
                }
            },
            deleteSecret: { id in
                do { try keychainStore.delete(account: privateKeyAccount(for: id)) }
                catch KeychainError.itemNotFound { }

                do { try keychainStore.delete(account: mnemonicAccount(for: id)) }
                catch KeychainError.itemNotFound { }
            },
            deleteAll: {
                try keychainStore.deleteAll()
            }
        )
    }
}

extension DependencyValues {
    var walletSecretRepository: WalletSecretRepository {
        get { self[WalletSecretRepository.self] }
        set { self[WalletSecretRepository.self] = newValue }
    }
}

private struct SecretPayload: Codable {
    let type: String
    let value: String
    let chain: String?
    let subtype: String?
}

private func decodeSecret(from data: Data) throws -> WalletSource {
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

private func privateKeyAccount(for id: UUID) -> String {
    "wallet_\(id.uuidString)"
}

private func mnemonicAccount(for id: UUID) -> String {
    "wallet_mnemonic_\(id.uuidString)"
}
