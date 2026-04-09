//
//  AccountDeploy.swift
//  xWallet
//
//  Created by Xueliang Zhu on 7/4/26.
//

import ComposableArchitecture
import Foundation
import MultiChainKit
import BigInt

@Reducer
struct AccountDeploy {
    
    enum Phase: Equatable {
        case checkBalance
        case insufficientFunds
        case estimating
        case readyToDeploy
        case deploying
        case pending(String)
        case success
        case failure
    }

    @ObservableState
    struct State: Equatable {
        var phase: Phase = .checkBalance
        var identityId: UUID
        var address: String
        var starknet: Starknet
        var starknetAccountType: StarknetAccountType
        var estimatedFee: StarknetFeeEstimate?
        var balance: BigUInt?
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case checkBalanceResponse(Result<BigUInt, Error>)
        case estimateFeeResponse(Result<StarknetFeeEstimate, Error>)
        case deployTapped
        case deployResponse(Result<String, Error>)
        case pollStatus
        case pollStatusResponse(Result<Bool, Error>)
        case retryTapped
    }

    enum CancelID {
        case pollStatus
    }

    @Dependency(\.walletClient) var walletClient
    @Dependency(\.starknetProvider) var starknetProvider

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.phase = .checkBalance
                state.errorMessage = nil
                return .run { [address = state.address, starknet = state.starknet, starknetProvider] send in
                    let balance = try await starknetProvider.getBalance(
                        address,
                        Starknet.Token.STRK.hexString,
                        starknet
                    )
                    await send(.checkBalanceResponse(.success(balance)))
                } catch: { error, send in
                    await send(.checkBalanceResponse(.failure(error)))
                }

            case .checkBalanceResponse(.success(let balance)):
                state.balance = balance
                if balance > .zero {
                    state.phase = .estimating
                    return .run { [identityId = state.identityId, walletClient, starknetProvider] send in
                        let account = try await walletClient.starknetAccount(identityId)
                        let fee = try await starknetProvider.estimateDeployFee(account)
                        await send(.estimateFeeResponse(.success(fee)))
                    } catch: { error, send in
                        await send(.estimateFeeResponse(.failure(error)))
                    }
                } else {
                    state.phase = .insufficientFunds
                    return .none
                }

            case .checkBalanceResponse(.failure(let error)):
                state.phase = .failure
                state.errorMessage = error.localizedDescription
                return .none

            case .estimateFeeResponse(.success(let fee)):
                state.estimatedFee = fee
                state.phase = .readyToDeploy
                return .none

            case .estimateFeeResponse(.failure(let error)):
                state.phase = .failure
                state.errorMessage = error.localizedDescription
                return .none

            case .deployTapped:
                state.phase = .deploying
                state.errorMessage = nil
                return .run { [identityId = state.identityId, walletClient, starknetProvider] send in
                    let account = try await walletClient.starknetAccount(identityId)
                    let txHash = try await starknetProvider.deployAccount(account)
                    await send(.deployResponse(.success(txHash)))
                } catch: { error, send in
                    await send(.deployResponse(.failure(error)))
                }

            case .deployResponse(.success(let txHash)):
                state.phase = .pending(txHash)
                return .send(.pollStatus)

            case .deployResponse(.failure(let error)):
                state.phase = .failure
                state.errorMessage = error.localizedDescription
                return .none

            case .pollStatus:
                guard case .pending(let txHash) = state.phase else {
                    return .none
                }
                return .run { [starknet = state.starknet, starknetProvider] send in
                    let receipt = try await starknetProvider.waitForTransaction(txHash, starknet)
                    await send(.pollStatusResponse(.success(receipt.isSuccess)))
                } catch: { error, send in
                    await send(.pollStatusResponse(.failure(error)))
                }
                .cancellable(id: CancelID.pollStatus, cancelInFlight: true)

            case .pollStatusResponse(.success(let isSuccess)):
                if isSuccess {
                    state.phase = .success
                    state.errorMessage = nil
                } else {
                    state.phase = .failure
                    state.errorMessage = "Deploy transaction reverted."
                }
                return .none

            case .pollStatusResponse(.failure(let error)):
                state.phase = .failure
                state.errorMessage = error.localizedDescription
                return .none

            case .retryTapped:
                state.phase = .checkBalance
                state.estimatedFee = nil
                state.balance = nil
                state.errorMessage = nil
                return .merge(
                    .cancel(id: CancelID.pollStatus),
                    .send(.onAppear)
                )
            }
        }
    }
}
