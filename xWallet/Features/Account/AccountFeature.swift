//
//  AccountState.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/1/26.
//

import Foundation
import WalletCore

struct AccountState: Equatable {
    var address: String? = nil
    var isUnlocked: Bool = false
    var errorMessage: String? = nil
}

enum AccountAction: Equatable {
    case onAppear
    case importPrivateKeyTapped(String)
    case importResult(Result<String, WalletError>)
    case lockTapped
}

struct AccountReducer: Reducer {
    typealias State = AccountState
    typealias Action = AccountAction

    private let keychain = KeychainService()
    private let keyPrivateKey = "evm_private_key"   // Keychain item key

    @MainActor
    func reduce(into state: inout AccountState, action: AccountAction, send: @escaping (Action) -> Void) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            do {
                let pkData = try keychain.loadData(account: keyPrivateKey)
                if let address = try? deriveEvmAddress(privateKey: pkData) {
                    state.address = address
                    state.isUnlocked = true
                }
            } catch {
                
            }
            return nil

        case .importPrivateKeyTapped(let hex):
            state.errorMessage = nil

            let input = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            return Task { @MainActor in
                do {
                    let pkData = try parsePrivateKeyHex(input)
                    let address = try deriveEvmAddress(privateKey: pkData)
                    try keychain.saveData(pkData, account: keyPrivateKey)
                    send(.importResult(.success(address)))
                } catch {
                    send(.importResult(.failure(.message(error.localizedDescription))))
                }
            }

        case .importResult(let result):
            switch result {
            case .success(let address):
                state.address = address
                state.isUnlocked = true
                state.errorMessage = nil
            case .failure(let err):
                state.errorMessage = err.message
                state.isUnlocked = false
            }
            return nil

        case .lockTapped:
            state.isUnlocked = false
            state.address = nil
            return nil
        }
    }

    // MARK: - Helpers

    private func parsePrivateKeyHex(_ hex: String) throws -> Data {
        let clean = hex.lowercased().hasPrefix("0x") ? String(hex.dropFirst(2)) : hex.lowercased()
        guard clean.count == 64 else { throw WalletError.message("Private key must be 64 hex chars") }
        guard let data = Data(hexString: clean) else { throw WalletError.message("Invalid hex") }
        return data
    }

    private func deriveEvmAddress(privateKey: Data) throws -> String {
        guard let pk = PrivateKey(data: privateKey) else {
            throw WalletError.message("Invalid private key bytes")
        }
        let pub = pk.getPublicKeySecp256k1(compressed: false)
        let addr = CoinType.ethereum.deriveAddressFromPublicKey(publicKey: pub)
        return addr
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        var data = Data()
        data.reserveCapacity(hexString.count / 2)

        var idx = hexString.startIndex
        for _ in 0..<(hexString.count / 2) {
            let next = hexString.index(idx, offsetBy: 2)
            let byteString = hexString[idx..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
}
