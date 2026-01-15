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
    var pendingSaveURL: String? = nil
    var isValid: Bool = false
    
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
            state.isValid = isUrlValid(state.rpcURL)
            return nil
        case .rpcURLChanged(let value):
            state.rpcURL = value
            state.isValid = isUrlValid(value)
            return nil
        case .saveTapped(let url):
            guard state.isValid else { return nil }
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if case .connected = state.connectionStatus {
                UserDefaults.standard.set(trimmed, forKey: "rpc_url")
                return nil
            } else {
                state.isChecking = true
                state.connectionStatus = .idle
                state.chainId = nil
                state.pendingSaveURL = trimmed
                return checkTask(url: state.rpcURL, send: send)
            }
        case .checkTapped:
            guard state.isValid else {
                state.connectionStatus = .failed("Invalid URL")
                return nil
            }
            state.isChecking = true
            state.connectionStatus = .idle
            state.chainId = nil
            return checkTask(url: state.rpcURL, send: send)
        case .checkResponse(let result):
            state.isChecking = false
            switch result {
            case .success(let chainId):
                state.chainId = chainId
                state.connectionStatus = .connected
                if let url = state.pendingSaveURL {
                    UserDefaults.standard.set(url, forKey: "rpc_url")
                    state.pendingSaveURL = nil
                }
            case .failure(let err):
                state.connectionStatus = .failed(err.message)
            }
            return nil
        }
    }
    
    private func checkTask(url: String, send: @escaping (SettingsAction) -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
                let rpc = EthereumRPC(rpcURL: url)
                let chainId = try await rpc.getChainId()
                send(.checkResponse(.success(chainId)))
            } catch {
                send(.checkResponse(.failure(.message(error.localizedDescription))))
            }
        }
    }
    
    private func isUrlValid(_ url: String) -> Bool {
        return url.hasPrefix("https://")
    }
}
