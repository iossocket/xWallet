//
//  ChainRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import EthereumKit
import BigInt

protocol ChainRepositoryProtocol {
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance
    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance]
    func transfer(to address: String, token: Token?)
}

struct EvmChainRepository: ChainRepositoryProtocol {
    
    private let datasource: ChainDataSource
    
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        let provider = EthereumProvider(chain: chain.toEvmChain())
        guard let evmAddr = EthereumAddress(address) else {
            throw TokenRepositoryError.invalidAddress(address)
        }
        
        let ethHex: String = try await provider.send(
            request: EthereumRequestBuilder.getBalanceRequest(address: evmAddr, block: .latest)
        )
        let cleaned = ethHex.lowercased().hasPrefix("0x")
            ? String(ethHex.dropFirst(2)) : ethHex
        let nativeWei = BigUInt(cleaned, radix: 16) ?? .zero

        guard let tokens = try? await datasource.listTokens(by: chain) else {
            throw TokenRepositoryError.invalidChain(chain.chainId)
        }
        
        var tokenBalances: [TokenBalance] = []
        try await withThrowingTaskGroup(of: TokenBalance?.self) { group in
            for token in tokens {
                group.addTask {
                    guard let contractAddr = EthereumAddress(token.contractAddress),
                          let owner = EthereumAddress(address) else {
                        return nil
                    }
                    
                    let contract = try EthereumContract(
                        address: contractAddr,
                        abiJson: ERC20ABI.json,
                        provider: provider
                    )
                    let bal: BigUInt = try await contract.readSingle(
                        functionName: "balanceOf",
                        args: [.address(owner)]
                    )
                    
                    guard bal > .zero else {
                        return nil
                    }
                    
                    return TokenBalance(
                        chainId: String(chain.chainId),
                        contractAddress: token.contractAddress,
                        symbol: token.symbol,
                        name: token.name,
                        decimals: token.decimals,
                        rawBalance: bal
                    )
                }
            }
            
            for try await balance in group {
                if let balance {
                    tokenBalances.append(balance)
                }
            }
        }
        
        return ChainBalance(
            chainId: String(chain.chainId),
            chainType: .evm,
            chainName: chain.name,
            symbol: chain.symbol,
            decimals: chain.decimals,
            nativeBalance: nativeWei,
            tokens: tokenBalances
        )
    }
    
    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance] {
        fatalError()
    }
    
    func transfer(to address: String, token: Token?) {
        fatalError()
    }
}

struct StarknetChainRepository: ChainRepositoryProtocol {
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        fatalError()
    }
    
    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance] {
        fatalError()
    }
    
    func transfer(to address: String, token: Token?) {
        fatalError()
    }
}


enum TokenRepositoryError: Error {
    case invalidAddress(String)
    case invalidChain(String)
}



