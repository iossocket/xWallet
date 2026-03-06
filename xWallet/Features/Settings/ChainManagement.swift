//
//  ChainManagement.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import ComposableArchitecture
import EthereumKit
import Foundation

enum ConnectionStatus: Equatable {
    case idle
    case connected
    case failed(String)
}

@Reducer
struct ChainManagement {
    @ObservableState
    struct State: Equatable {
        @Presents var chainDetail: ChainDetail.State?
        var chains: [EvmChainRecord] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action {
        case chainDetail(PresentationAction<ChainDetail.Action>)
        case onAppear
        case loadChainsResponse(Result<[EvmChainRecord], Error>)
        case batchInsertChains(Result<[EvmChainRecord], Error>)
        case chainRowTapped(EvmChainRecord)
        case chainToggled(EvmChainRecord, Bool)
        case toggleResponse(Result<EvmChainRecord?, Error>)
    }

    @Dependency(\.chainRegistry) var chainRegistry

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.loadChainsResponse(
                        Result { try await chainRegistry.listAllChains() }
                    ))
                }

            case .loadChainsResponse(.success(let chains)):
                if chains.count > 0 {
                    state.isLoading = false
                    state.chains = chains
                    return .none
                } else {
                    let chains = EvmChainPresets.presetsWithEnabledStatus()
                    return .run { send in
                        await send(.batchInsertChains(
                            Result { try await chainRegistry.batchInsertChains(chains)}
                        ))

                    }
                }

            case .loadChainsResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .batchInsertChains(.success(let chains)):
                state.isLoading = false
                state.chains = chains
                return .none
            
            case .batchInsertChains(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .chainRowTapped(let chain):
                state.chainDetail = ChainDetail.State(chain: chain)
                return .none

            case .chainToggled(let chain, let enabled):
                return .run { send in
                    await send(.toggleResponse(
                        Result { try await chainRegistry.updateChain(chain, enabled) }
                    ))
                }

            case .toggleResponse(.success):
                state.errorMessage = nil
                return .run { send in
                    await send(.loadChainsResponse(
                        Result { try await chainRegistry.listAllChains() }
                    ))
                }

            case .toggleResponse(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none

            case .chainDetail:
                return .none
            }
        }
        .ifLet(\.$chainDetail, action: \.chainDetail) {
            ChainDetail()
        }
    }
}

@Reducer
struct ChainDetail {
    @ObservableState
    struct State: Equatable {
        var chain: EvmChainRecord
        var customRpcURL: String
        var isTestingConnection = false
        var connectionStatus: ConnectionStatus = .idle
        var isSaving = false

        init(chain: EvmChainRecord) {
            self.chain = chain
            self.customRpcURL = chain.rpcURL
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case testConnectionTapped
        case connectionResponse(Result<Int, Error>)
        case saveButtonTapped
        case saveResponse(Result<EvmChainRecord?, Error>)
    }

    @Dependency(\.evmProvider) var evmProvider
    @Dependency(\.chainRegistry) var chainRegistry
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .testConnectionTapped:
                guard let url = URL(string: state.customRpcURL),
                      url.scheme == "https" || url.scheme == "http",
                      url.host != nil else {
                    state.connectionStatus = .failed("Invalid URL")
                    return .none
                }
                state.isTestingConnection = true
                state.connectionStatus = .idle
                let chain = state.chain
                return .run { send in
                    do {
                        let provider = evmProvider.provider(chain)
                        let hex: String = try await provider.send(
                            request: provider.chainIdRequest()
                        )
                        let chainId = Int(hex.dropFirst(2), radix: 16) ?? 0
                        await send(.connectionResponse(.success(chainId)))
                    } catch {
                        await send(.connectionResponse(.failure(error)))
                    }
                }

            case .connectionResponse(.success(let chainId)):
                state.isTestingConnection = false
                if chainId == Int(state.chain.chainId) {
                    state.connectionStatus = .connected
                } else {
                    state.connectionStatus = .failed("Chain ID mismatch: expected \(state.chain.chainId), got \(chainId)")
                }
                return .none

            case .connectionResponse(.failure(let error)):
                state.isTestingConnection = false
                state.connectionStatus = .failed(error.localizedDescription)
                return .none

            case .saveButtonTapped:
                guard let url = URL(string: state.customRpcURL),
                      url.scheme == "https" || url.scheme == "http",
                      url.host != nil else {
                    state.connectionStatus = .failed("Invalid URL")
                    return .none
                }
                state.isSaving = true
                let chain = state.chain
                return .run { send in
                    await send(.saveResponse(
                        Result { try await chainRegistry.updateChain(chain, true) }
                    ))
                }

            case .saveResponse(.success):
                state.isSaving = false
                return .run { _ in await dismiss() }

            case .saveResponse(.failure(let error)):
                state.isSaving = false
                state.connectionStatus = .failed(error.localizedDescription)
                return .none
            }
        }
    }
}
