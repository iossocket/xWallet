//
//  ERC20Client.swift
//  xWallet
//
//  Created by Xueliang Zhu on 27/2/26.
//

import Foundation
import EthereumKit
import MultiChainKit
import BigInt
import Dependencies

private let erc20ABI = """
[
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{ "name": "", "type": "string" }],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "name": "", "type": "string" }],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "name": "", "type": "uint8" }],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{ "name": "owner", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "", "type": "uint256" }],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      { "name": "to", "type": "address" },
      { "name": "value", "type": "uint256" }
    ],
    "name": "transfer",
    "outputs": [{ "name": "", "type": "bool" }],
    "type": "function"
  }
]
"""

// ERC-20 代币元数据（绑定到具体链）
struct ERC20Token: Equatable, Identifiable, Sendable {
    let chainId: UInt64
    let address: String
    let symbol: String
    let decimals: UInt8
    let name: String
    var id: String { "\(chainId):\(address.lowercased())" }
}

struct ERC20Client {
    var balanceOf: @Sendable (String, ERC20Token, EvmChainRecord) async throws -> BigUInt
    var transfer: @Sendable (String, BigUInt, ERC20Token, EthereumSignableAccount) async throws -> String
    var tokenInfo: @Sendable (String, EvmChainRecord) async throws -> ERC20Token
}

extension ERC20Client: DependencyKey {
    static var liveValue: ERC20Client {
        ERC20Client(
            balanceOf: { ownerAddress, token, chain in
                guard let contractAddr = EthereumAddress(token.address),
                      let owner = EthereumAddress(ownerAddress) else {
                    throw ERC20Error.invalidAddress
                }

                let provider = EthereumProvider(chain: chain.toChain())
                let contract = try EthereumContract(
                    address: contractAddr,
                    abiJson: erc20ABI,
                    provider: provider
                )

                let balance: BigUInt = try await contract.readSingle(
                    functionName: "balanceOf",
                    args: [.address(owner)]
                )
                return balance
            },
            transfer: { toAddress, amount, token, account in
                guard let contractAddr = EthereumAddress(token.address),
                      let to = EthereumAddress(toAddress) else {
                    throw ERC20Error.invalidAddress
                }
                
                guard let provider = account.provider else {
                    throw ERC20Error.invalidAccount
                }

                let contract = try EthereumContract(
                    address: contractAddr,
                    abiJson: erc20ABI,
                    provider: provider
                )

                return try await contract.write(
                    functionName: "transfer",
                    args: [
                        .address(to),
                        .uint256(Wei(amount))
                    ],
                    account: account
                )
            },
            tokenInfo: { contractAddress, chain in
                guard let contractAddr = EthereumAddress(contractAddress) else {
                    throw ERC20Error.invalidAddress
                }
                let provider = EthereumProvider(chain: chain.toChain())
                let contract = try EthereumContract(
                    address: contractAddr,
                    abiJson: erc20ABI,
                    provider: provider
                )
                
                async let symbol: String = contract.readSingle(functionName: "symbol")
                async let decimals: UInt8 = contract.readSingle(functionName: "decimals")
                async let name: String = contract.readSingle(functionName: "name")
                let (s, d, n) = try await (symbol, decimals, name)
                
                return ERC20Token(
                    chainId: provider.chain.chainId,
                    address: contractAddress,
                    symbol: s,
                    decimals: d,
                    name: n
                )
            }
        )
    }

    static var testValue: ERC20Client {
        ERC20Client(
            balanceOf: { _, _, _ in BigUInt(1_000_000_000_000_000_000) }, // 1 token
            transfer: { _, _, _, _ in "0xdeadbeef" },
            tokenInfo: { address, chain in
                ERC20Token(
                    chainId: chain.chainId,
                    address: address,
                    symbol: "TEST",
                    decimals: 18,
                    name: "Test Token"
                )
            }
        )
    }
}

extension DependencyValues {
    var erc20Client: ERC20Client {
        get { self[ERC20Client.self] }
        set { self[ERC20Client.self] = newValue }
    }
}

enum ERC20Error: Error, LocalizedError {
    case invalidAddress
    case contractCallFailed
    case invalidAccount
}
