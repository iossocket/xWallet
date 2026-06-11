//
//  StarknetRPCService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation
import Dependencies
import MultiChainKit
import MultiChainCore
import BigInt


struct StarknetRPCService {
    var getBalance: @Sendable (_ address: String, _ tokenContract: String, _ chain: Starknet) async throws -> BigUInt
    var isAccountDeployed: @Sendable (_ address: String, _ chain: Starknet) async throws -> Bool
    var waitForTransaction: @Sendable (_ hash: String, _ chain: Starknet) async throws -> StarknetReceipt
    var estimateDeployFee: @Sendable (_ account: StarknetAccount) async throws -> StarknetFeeEstimate
    var deployAccount: @Sendable (_ account: StarknetAccount) async throws -> String
}

extension StarknetRPCService: DependencyKey {
    static var liveValue: StarknetRPCService {
        return StarknetRPCService { address, tokenContract, chain in
            let provider = StarknetProvider(chain: chain)
            guard let tokenAddress = Felt(tokenContract), let accountAddress = Felt(address) else {
                return .zero
            }
            let call = StarknetCall(contractAddress: tokenAddress, entrypoint: "balance_of", calldata: [accountAddress])
            let request = StarknetRequestBuilder.callRequest(call: call, block: .latest)
            let result: [String] = try await provider.send(request: request)
            guard result.count >= 2, let low = Felt(result[0]), let high = Felt(result[1]) else {
                return .zero
            }
            return low.bigUIntValue + high.bigUIntValue * (BigUInt(1) << 128)
        } isAccountDeployed: { address, chain in
            let provider = StarknetProvider(chain: chain)
            guard let strkAddress = StarknetAddress(address) else {
                return false
            }
            let req = StarknetRequestBuilder.getClassHashAtRequest(address: strkAddress)
            do {
                let _: String = try await provider.send(request: req)
                return true
            } catch {
                return false
            }
        } waitForTransaction: { hash, chain in
            let provider = StarknetProvider(chain: chain)
            guard let felt = Felt(hash) else {
                throw StarknetProviderError.invalidHash
            }
            return try await provider.waitForTransaction(hash: felt)
        } estimateDeployFee: { account in
            guard let provider = account.provider else {
                throw StarknetProviderError.missingProvider
            }
            let deployTx = try buildDeployAccountTx(account: account, resourceBounds: .zero)
            let signed = try account.signDeployAccountV3(deployTx)
            let request = StarknetRequestBuilder.estimateFeeRequest(deployV3: signed)
            let results: [StarknetFeeEstimate] = try await provider.send(request: request)
            guard let estimate = results.first else {
                throw StarknetProviderError.emptyEstimate
            }
            return estimate
        } deployAccount: { account in
            guard let provider = account.provider else {
                throw StarknetProviderError.missingProvider
            }

            // 1. Estimate fee
            let estimateTx = try buildDeployAccountTx(account: account, resourceBounds: .zero)
            let signedEstimate = try account.signDeployAccountV3(estimateTx)
            let estimateRequest = StarknetRequestBuilder.estimateFeeRequest(deployV3: signedEstimate)
            let results: [StarknetFeeEstimate] = try await provider.send(request: estimateRequest)
            guard let estimate = results.first else {
                throw StarknetProviderError.emptyEstimate
            }

            // 2. Build real deploy tx with estimated resource bounds
            let resourceBounds = estimate.toResourceBounds(multiplier: 1.5)
            let deployTx = try buildDeployAccountTx(account: account, resourceBounds: resourceBounds)
            let signed = try account.signDeployAccountV3(deployTx)
            return try await account.sendTransaction(.deployAccountV3(signed))
        }
    }
    
    static var testValue: StarknetRPCService {
        StarknetRPCService(
            getBalance: { _, _, _ in BigUInt.zero },
            isAccountDeployed: { _, _ in false },
            waitForTransaction: { _, _ in
                fatalError("StarknetRPCService.waitForTransaction: override in withDependencies")
            },
            estimateDeployFee: { _ in
                fatalError("StarknetRPCService.estimateDeployFee: override in withDependencies")
            },
            deployAccount: { _ in
                fatalError("StarknetRPCService.deployAccount: override in withDependencies")
            }
        )
    }
}

extension DependencyValues {
    var starknetRPCService: StarknetRPCService {
        get { self[StarknetRPCService.self] }
        set { self[StarknetRPCService.self] = newValue }
    }
}

enum StarknetProviderError: Error {
    case invalidHash
    case emptyEstimate
    case missingAccountType
    case missingProvider
}

private func buildDeployAccountTx(
    account: StarknetAccount,
    resourceBounds: StarknetResourceBoundsMapping
) throws -> StarknetDeployAccountV3 {
    guard let accountType = account.accountType, let pubKey = account.publicKeyFelt else {
        throw StarknetProviderError.missingAccountType
    }
    return StarknetDeployAccountV3(
        classHash: accountType.classHash,
        contractAddressSalt: pubKey,
        constructorCalldata: accountType.constructorCalldata(publicKey: pubKey),
        resourceBounds: resourceBounds,
        nonce: .zero,
        chainId: account.chain.chainId
    )
}
