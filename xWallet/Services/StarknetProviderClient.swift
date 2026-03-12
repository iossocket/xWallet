//
//  StarknetProviderClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation
import Dependencies
import MultiChainKit
import MultiChainCore
import BigInt


enum StarknetTokenContracts {
    static let eth = Felt("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    static let strk = Felt("0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")!
}

struct StarknetProviderClient {
    var getBalance: @Sendable (_ address: String, _ tokenContract: String, _ chain: Starknet) async throws -> BigUInt
    var isAccountDeployed: @Sendable (_ address: String, _ chain: Starknet) async throws -> Bool
    var waitForTransaction: @Sendable (_ hash: String, _ chain: Starknet) async throws -> StarknetReceipt
}

extension StarknetProviderClient: DependencyKey {
    static var liveValue: StarknetProviderClient {
        return StarknetProviderClient { address, tokenContract, chain in
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
        }
    }
    
    static var testValue: StarknetProviderClient {
        StarknetProviderClient(
            getBalance: { _, _, _ in BigUInt.zero },
            isAccountDeployed: { _, _ in false },
            waitForTransaction: { _, _ in
                fatalError("StarknetProviderClient.waitForTransaction: override in withDependencies")
            }
        )
    }
}

extension DependencyValues {
    var starknetProvider: StarknetProviderClient {
        get { self[StarknetProviderClient.self] }
        set { self[StarknetProviderClient.self] = newValue }
    }
}

enum StarknetProviderError: Error {
    case invalidHash
}
