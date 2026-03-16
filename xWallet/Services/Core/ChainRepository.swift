//
//  ChainRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import EthereumKit
import MultiChainCore
import BigInt
import StarknetKit

protocol ChainRepositoryProtocol {
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance
    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance]
//    func transfer(to address: String, from account: any MultiChainCore.Account, token: Token?) async throws -> String
}

struct EvmChainRepository: ChainRepositoryProtocol {
    private let datasource: ChainDataSource
    
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        let provider = EthereumProvider(chain: chain.toEvmChain())
        guard let evmAddr = EthereumAddress(address) else {
            throw ChainError.invalidAddress
        }
        
        let ethHex: String = try await provider.send(
            request: EthereumRequestBuilder.getBalanceRequest(address: evmAddr, block: .latest)
        )
        let cleaned = ethHex.lowercased().hasPrefix("0x")
            ? String(ethHex.dropFirst(2)) : ethHex
        let nativeWei = BigUInt(cleaned, radix: 16) ?? .zero

        guard let tokens = try? await datasource.listTokens(by: chain) else {
            throw ChainError.other
        }
        
        var tokenBalances: [TokenBalance] = []
        await withTaskGroup(of: TokenBalance?.self) { group in
            for token in tokens {
                group.addTask {
                    do {
                        guard let contractAddr = EthereumAddress(token.contractAddress),
                              let owner = EthereumAddress(address) else {
                            return nil
                        }
                        let contract = try EthereumContract(
                            address: contractAddr,
                            abiJson: ERC20ABI.evm,
                            provider: provider
                        )
                        let bal: BigUInt = try await contract.readSingle(
                            functionName: "balanceOf",
                            args: [.address(owner)]
                        )
                        return TokenBalance(
                            chainId: String(chain.chainId),
                            contractAddress: token.contractAddress,
                            symbol: token.symbol,
                            name: token.name,
                            decimals: token.decimals,
                            rawBalance: bal
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            for await balance in group {
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
        var chainBalances: [ChainBalance] = []
        await withTaskGroup(of: ChainBalance?.self) { group in
            for chain in chains {
                group.addTask {
                    do {
                        return try await fetchTokenBalances(address: address, chain: chain)
                    } catch {
                        return nil
                    }
                }
            }
            for await chainBalance in group {
                if let chainBalance {
                    chainBalances.append(chainBalance)
                }
            }
        }
        return chainBalances
    }
    
//    func transfer(to address: String, from account: any MultiChainCore.Account, amount: BigUInt, token: Token?) async throws -> String {
//        if let token = token {
//            guard let contractAddr = EthereumAddress(token.contractAddress),
//                  let to = EthereumAddress(address) else {
//                throw ChainError.invalidAddress
//            }
//            
//            guard let provider = account.provider else {
//                throw ChainError.noProvider
//            }
//
//            let contract = try EthereumContract(
//                address: contractAddr,
//                abiJson: ERC20ABI.json,
//                provider: provider as! EthereumProvider
//            )
//
//            return try await contract.write(
//                functionName: "transfer",
//                args: [
//                    .address(to),
//                    .uint256(Wei(amount))
//                ],
//                account: account as! EthereumAccount
//            )
//        }
//        
//        return ""
//    }
}

struct StarknetChainRepository: ChainRepositoryProtocol {
    private let datasource: ChainDataSource
    
    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        let provider = StarknetProvider(chain: chain.toStrkChain())
        guard let owner = StarknetAddress(address) else {
            throw ChainError.invalidAddress
        }
        
        let tokens = ERC20TokenList.tokens(for: chain.chainId).map {
            Token(id: $0.id, chainId: $0.chainId, name: $0.name, symbol: $0.symbol, decimals: $0.decimals, contractAddress: $0.address, chainFK: "")
        }
//        TODO: add tokens from db
//        guard let tokens = try? await datasource.listTokens(by: chain) else {
//            throw ChainError.other
//        }
        
        var tokenBalances: [TokenBalance] = []
        await withTaskGroup(of: TokenBalance?.self) { group in
            for token in tokens {
                group.addTask {
                    do {
                        let contract = try StarknetContract(
                            address: token.contractAddress,
                            abiJson: ERC20ABI.strk,
                            provider: provider
                        )
                        let bal: BigUInt = try await contract.readSingle(
                            function: "balanceOf",
                            args: [.contractAddress(Felt(owner.checksummed)!)]
                        )
                        return TokenBalance(
                            chainId: String(chain.chainId),
                            contractAddress: token.contractAddress,
                            symbol: token.symbol,
                            name: token.name,
                            decimals: token.decimals,
                            rawBalance: bal
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            for await balance in group {
                if let balance {
                    tokenBalances.append(balance)
                }
            }
        }
        
        let nativeBalance = tokenBalances.filter { tokenBalance in
            tokenBalance.contractAddress == Starknet.Token.STRK.hexString
        }
        
        return ChainBalance(
            chainId: chain.chainId,
            chainType: .starknet,
            chainName: chain.name,
            symbol: chain.symbol,
            decimals: chain.decimals,
            nativeBalance: nativeBalance.count > 0 ? nativeBalance[0].rawBalance : 0,
            tokens: tokenBalances.filter { tokenBalance in
                tokenBalance.contractAddress != Starknet.Token.STRK.hexString
            }
        )
    }
    
    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance] {
        var chainBalances: [ChainBalance] = []
        await withTaskGroup(of: ChainBalance?.self) { group in
            for chain in chains {
                group.addTask {
                    do {
                        return try await fetchTokenBalances(address: address, chain: chain)
                    } catch {
                        return nil
                    }
                }
            }
            for await chainBalance in group {
                if let chainBalance {
                    chainBalances.append(chainBalance)
                }
            }
        }
        return chainBalances
    }
}
