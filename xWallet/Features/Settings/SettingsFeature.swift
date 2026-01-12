//
//  SettingsFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/1/26.
//

import Foundation

enum ConnectionStatus: Equatable {
    case idle
    case connected
    case failed(String)
}

struct SettingsState: Equatable {
    var rpcURL: String = ""
    var isValid: Bool = true
    
    var isChecking: Bool = false
    var connectionStatus: ConnectionStatus = .idle
    var chainId: Int? = nil
}

enum SettingsAction: Equatable {
    case onAppear
    case rpcURLChanged(String)
    case checkTapped
    case checkResponse(Result<Int, WalletError>)
    case saveTapped(String)
}

struct SettingsReducer: Reducer {
    typealias State = SettingsState
    typealias Action = SettingsAction
    
    @MainActor
    func reduce(into state: inout SettingsState, action: SettingsAction, send: @escaping (SettingsAction) -> Void) -> Task<Void, Never>? {
        switch action {
        case .onAppear:
            state.rpcURL = UserDefaults.standard.string(forKey: "rpc_url") ?? "https://rpc.sepolia.org"
            state.isValid = true
            return nil
        case .rpcURLChanged(let value):
            state.rpcURL = value
            state.isValid = value.hasPrefix("https://")
            return nil
        case .saveTapped(let url):
            guard state.isValid else { return nil }
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: "rpc_url")
            return nil
        case .checkTapped:
            guard state.isValid else {
                state.connectionStatus = .failed("Invalid URL")
                return nil
            }
            state.isChecking = true
            state.connectionStatus = .idle
            state.chainId = nil

            let url = state.rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let rpc = EthereumRPC(rpcURL: url)

            return Task { @MainActor in
                do {
                    let chainId = try await rpc.getChainId()
                    send(.checkResponse(.success(chainId)))
                } catch {
                    send(.checkResponse(.failure(.message(error.localizedDescription))))
                }
            }
        case .checkResponse(let result):
            state.isChecking = false
            switch result {
            case .success(let chainId):
                state.chainId = chainId
                state.connectionStatus = .connected
            case .failure(let err):
                state.connectionStatus = .failed(err.message)
            }
            return nil
        }
    }
}
