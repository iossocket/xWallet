//
//  ChainBalance.swift
//  xWallet
//
//  Created by Xueliang Zhu on 6/3/26.
//

import BigInt

struct ChainBalance: Equatable, Identifiable, Sendable {
    let chainId: String           // "1", "11155111", "starknet", etc.
    let chainType: ChainType
    let chainName: String
    let symbol: String
    let decimals: Int
    let nativeBalance: BigUInt
    let tokens: [TokenBalance]

    var id: String { chainId }

    var nativeFormatted: String {
        UnitFormatter.formatWei(nativeBalance, decimals: decimals)
    }
}

struct TokenBalance: Equatable, Identifiable, Sendable {
    let chainId: String
    let contractAddress: String
    let symbol: String
    let name: String
    let decimals: Int
    let rawBalance: BigUInt

    var id: String { "\(chainId):\(contractAddress.lowercased())" }

    var formatted: String {
        UnitFormatter.formatWei(rawBalance, decimals: decimals)
    }
}
