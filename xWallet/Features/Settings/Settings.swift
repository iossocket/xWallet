//
//  Settings.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import ComposableArchitecture

enum ConnectionStatus: Equatable {
    case idle
    case connected
    case failed(String)
}

@Reducer
struct Settings {
    @ObservableState
    struct State: Equatable {
        var chainId: Int?
        var connectionStatus: ConnectionStatus = .idle
        var isChecking = false
        var isValid = false
        var pendingSaveURL: String?
        var rpcURL = ""
    }
    
    enum CancelID {
        case rpcCheck
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case checkButtonTapped
        case checkResponse(Result<Int, Error>)
        case onAppear
        case rpcURLChanged(String)
        case saveButtonTapped(String)
    }
    
    @Dependency(\.keyValueStorage) var keyValueStorage
    @Dependency(\.evmRpcClient) var evmRpcClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                state.rpcURL = keyValueStorage.load(forKey: "rpc_url")
                    ?? "https://rpc.sepolia.org"
                state.isValid = state.rpcURL.hasPrefix("https://")
                return .none

            case .rpcURLChanged(let value):
                state.rpcURL = value
                state.isValid = value.hasPrefix("https://")
                return .none

            case .checkButtonTapped:
                guard state.isValid else {
                    state.connectionStatus = .failed("Invalid URL")
                    return .none
                }
                state.isChecking = true
                state.connectionStatus = .idle
                state.chainId = nil
                let url = state.rpcURL.trimmingCharacters(in: .whitespacesAndNewlines)
                return .run { send in
                    do {
                        let chainId = try await evmRpcClient.getChainId(url)
                        await send(.checkResponse(.success(chainId)))
                    } catch {
                        await send(.checkResponse(.failure(error)))
                    }
                }.cancellable(id: CancelID.rpcCheck, cancelInFlight: true)

            case .checkResponse(.success(let chainId)):
                state.isChecking = false
                state.chainId = chainId
                state.connectionStatus = .connected
                if let url = state.pendingSaveURL {
                    keyValueStorage.save(value: url, forKey: "rpc_url")
                    state.pendingSaveURL = nil
                }
                return .none

            case .checkResponse(.failure(let error)):
                state.isChecking = false
                state.connectionStatus = .failed(error.localizedDescription)
                return .none

            case .saveButtonTapped(let url):
                guard state.isValid else { return .none }
                let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
                if case .connected = state.connectionStatus {
                    keyValueStorage.save(value: trimmed, forKey: "rpc_url")
                    return .none
                } else {
                    state.pendingSaveURL = trimmed
                    return .send(.checkButtonTapped)
                }
            }
        }
    }
}
