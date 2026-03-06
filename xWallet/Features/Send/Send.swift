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
        var chain: EvmChainRecord
        var availableAssets: IdentifiedArrayOf<AssetItem> = []
        var selectedAsset: AssetItem?
        var toAddress: String = ""
        var amount: String = ""
        var gasEstimate: String = ""
        var maxFeePerGas: String = ""
        var maxPriorityFeePerGas: String = ""
        var txHash: String?
        var preparedTx: EthereumTransaction?
        var errorMessage: String?
        var phase: Phase = .input
        
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
        case estimateGasTapped
        case estimateGasResponse(Result<GasEstimate, Error>)
        case confirmSendTapped
        case sendResponse(Result<String, Error>)
        case pollReceipt(String)
        case pollReceiptResponse(Result<Bool, Error>)
        case dismissError
    }
    
    struct GasEstimate: Equatable {
        let transaction: EthereumTransaction
        let maxFeePerGas: Wei
        let maxPriorityFeePerGas: Wei
        let gasLimit: UInt64
    }
    
    enum CancelID {
        case poll
    }
    
    @Dependency(\.walletClient) var walletClient
    @Dependency(\.evmProvider) var evmProvider
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .assetSelected(let asset):
                state.selectedAsset = asset
                state.amount = ""
                state.gasEstimate = ""
                state.maxFeePerGas = ""
                state.maxPriorityFeePerGas = ""
                state.preparedTx = nil
                state.phase = .input
                return .none

            case .estimateGasTapped:
                guard let toEthereumAddress = EthereumAddress(state.toAddress) else {
                    state.errorMessage = "Invalid address"
                    return .none
                }
                guard Wei.fromEther(state.amount) != nil else {
                    state.errorMessage = "Invalid amount"
                    return .none
                }
                state.phase = .estimating
                state.errorMessage = nil

                let amount = state.amount
                let chain = state.chain
                let selectedAsset = state.selectedAsset

                return .run { [walletClient] send in
                    do {
                        let account = try await walletClient.activeEvmAccount(EthereumProvider(chain: chain.toChain()))

                        let tx: EthereumTransaction
                        if let asset = selectedAsset, asset.id != "ETH" {
                            guard let token = ERC20TokenList.token(address: String(asset.id.split(separator: ":")[1]), chainId: chain.chainId) else {
                                throw SendError.invalidToken
                            }
                            guard let tokenAmount = UnitFormatter.parse(amount, decimals: token.decimals) else {
                                throw SendError.invalidAmount
                            }

                            let data = ABIValue.encodeCall(
                                signature: "transfer(address,uint256)",
                                arguments: [
                                    .address(toEthereumAddress),
                                    .uint256(Wei(tokenAmount))
                                ]
                            )

                            tx = try await account.prepareTransaction(
                                to: EthereumAddress(token.address)!,
                                value: .zero,
                                data: data
                            )
                        } else {
                            let value = Wei.fromEther(amount) ?? .zero
                            tx = try await account.prepareTransaction(
                                to: toEthereumAddress,
                                value: value
                            )
                        }

                        let estimate = GasEstimate(
                            transaction: tx,
                            maxFeePerGas: tx.maxFeePerGas ?? .zero,
                            maxPriorityFeePerGas: tx.maxPriorityFeePerGas ?? .zero,
                            gasLimit: tx.gasLimit
                        )
                        await send(.estimateGasResponse(.success(estimate)))
                    } catch {
                        await send(.estimateGasResponse(.failure(error)))
                    }
                }

            case .estimateGasResponse(.success(let estimate)):
                state.gasEstimate = "\(estimate.gasLimit)"
                state.maxFeePerGas = "\(estimate.maxFeePerGas.description) Gwei"
                state.maxPriorityFeePerGas = "\(estimate.maxPriorityFeePerGas.description) Gwei"
                state.preparedTx = estimate.transaction
                state.phase = .confirm
                return .none
            case .estimateGasResponse(.failure(let error)):
                state.phase = .input
                state.errorMessage = error.localizedDescription
                return .none
            case .confirmSendTapped:
                guard let preparedTx = state.preparedTx else {
                    state.phase = .failure("No prepared transaction")
                    return .none
                }
                state.phase = .sending
                let chain = state.chain
                return .run { [walletClient, providerFactory = evmProvider.provider, preparedTx] send in
                    await send(.sendResponse(Result {
                        var transaction = preparedTx
                        let account: EthereumSignableAccount = try await walletClient.activeEvmAccount(EthereumProvider(chain: chain.toChain()))
                        let provider = providerFactory(chain)
                        try account.sign(transaction: &transaction)
                        guard let raw = transaction.rawTransaction else {
                            throw SendError.invalidTransaction
                        }
                        return try await provider.send(request: provider.sendRawTransactionRequest(raw))
                    }))
                }
            case .sendResponse(.success(let txHash)):
                state.txHash = txHash
                state.phase = .pending(txHash)
                return .run { send in
                    await send(.pollReceipt(txHash))
                }
            case .sendResponse(.failure(let error)):
                state.phase = .failure(error.localizedDescription)
                return .none
            case .pollReceipt(let txHash):
                return .run { [provider = evmProvider.provider(state.chain)] send in
                    do {
                        _ = try await provider.waitForTransaction(hash: txHash)
                        await send(.pollReceiptResponse(.success(true)))
                    } catch {
                        await send(.pollReceiptResponse(.failure(error)))
                    }
                }.cancellable(id: CancelID.poll, cancelInFlight: true)
            case .pollReceiptResponse(.success(true)):
                if case .pending(let hash) = state.phase {
                    state.phase = .success(hash)
                }
                return .none
            case .pollReceiptResponse(.success(false)):
                return .none
            case .pollReceiptResponse(.failure(let error)):
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
