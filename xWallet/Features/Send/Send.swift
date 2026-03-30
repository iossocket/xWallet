//
//  Send.swift
//  xWallet
//
//  Created by Xueliang Zhu on 25/2/26.
//

import ComposableArchitecture
import EthereumKit
import MultiChainKit
import BigInt

@Reducer
struct Send {
    @ObservableState
    struct State: Equatable {
        var chain: Chain
        var availableAssets: IdentifiedArrayOf<AssetItem> = []
        var selectedAsset: AssetItem?
        var toAddress: String = ""
        var amount: String = ""
        var feeEstimate: FeeEstimate?
        var txHash: String?
        var errorMessage: String?
        var phase: Phase = .input
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet

        enum Phase: Equatable {
            case input
            case estimating
            case confirm
            case sending
            case pending(String)
            case success(String)
            case failure(String)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case assetSelected(AssetItem)
        case estimateFeeTapped
        case estimateFeeResponse(Result<FeeEstimate, Error>)
        case confirmSendTapped
        case sendResponse(Result<String, Error>)
        case waitForConfirmationResponse(Result<TxResult, Error>)
        case dismissError
    }

    enum CancelID {
        case poll
    }

    @Dependency(\.walletClient) var walletClient
    @Dependency(\.sendClient) var sendClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .assetSelected(let asset):
                state.selectedAsset = asset
                state.amount = ""
                state.feeEstimate = nil
                state.phase = .input
                return .none

            case .estimateFeeTapped:
                guard sendClient.validateAddress(state.toAddress, state.chain) else {
                    state.errorMessage = "Invalid address"
                    return .none
                }
                guard !state.amount.isEmpty, Double(state.amount) != nil else {
                    state.errorMessage = "Invalid amount"
                    return .none
                }
                state.phase = .estimating
                state.errorMessage = nil

                let request = SendRequest(
                    chain: state.chain,
                    toAddress: state.toAddress,
                    amount: state.amount,
                    asset: state.selectedAsset
                )
                let chain = state.chain

                return .run { [walletClient, sendClient] send in
                    await send(.estimateFeeResponse(Result {
                        let chainAccount = try await resolveChainAccount(chain: chain, walletClient: walletClient)
                        return try await sendClient.estimateFee(request, chainAccount)
                    }))
                }

            case .estimateFeeResponse(.success(let fee)):
                state.feeEstimate = fee
                state.phase = .confirm
                return .none

            case .estimateFeeResponse(.failure(let error)):
                state.phase = .input
                state.errorMessage = error.localizedDescription
                return .none

            case .confirmSendTapped:
                guard state.feeEstimate != nil else {
                    state.phase = .failure("No fee estimate")
                    return .none
                }
                state.phase = .sending
                let request = SendRequest(
                    chain: state.chain,
                    toAddress: state.toAddress,
                    amount: state.amount,
                    asset: state.selectedAsset
                )
                let chain = state.chain

                return .run { [walletClient, sendClient] send in
                    await send(.sendResponse(Result {
                        let chainAccount = try await resolveChainAccount(chain: chain, walletClient: walletClient)
                        return try await sendClient.send(request, chainAccount)
                    }))
                }

            case .sendResponse(.success(let txHash)):
                state.txHash = txHash
                state.phase = .pending(txHash)
                let chain = state.chain
                return .run { [sendClient] send in
                    await send(.waitForConfirmationResponse(Result {
                        try await sendClient.waitForConfirmation(txHash, chain)
                    }))
                }.cancellable(id: CancelID.poll, cancelInFlight: true)

            case .sendResponse(.failure(let error)):
                state.phase = .failure(error.localizedDescription)
                return .none

            case .waitForConfirmationResponse(.success(let result)):
                if case .pending(let hash) = state.phase {
                    switch result {
                    case .success:
                        state.phase = .success(hash)
                    case .reverted(let reason):
                        state.phase = .failure(reason ?? "Transaction reverted")
                    }
                }
                return .none

            case .waitForConfirmationResponse(.failure(let error)):
                state.phase = .failure(error.localizedDescription)
                return .cancel(id: CancelID.poll)

            case .dismissError:
                state.errorMessage = nil
                state.phase = .input
                return .none
            }
        }
    }
}

enum SendError: Error {
    case invalidAddress
    case invalidAmount
    case invalidToken
    case invalidTransaction
}

private func resolveChainAccount(chain: Chain, walletClient: WalletClient) async throws -> ChainAccount {
    switch chain.chainType() {
    case .evm:
        let provider = EthereumProvider(chain: chain.toEvmChain())
        let account = try await walletClient.activeEvmAccount(provider)
        return .evm(account, provider)
    case .starknet:
        let provider = StarknetProvider(chain: chain.toStrkChain())
        let account = try await walletClient.activeStarknetAccount()
        return .starknet(account, provider)
    }
}
