//
//  ChainBalance.swift
//  xWallet
//
//  Created by Xueliang Zhu on 6/3/26.
//

import BigInt
import EthereumKit

struct ChainBalance: Equatable, Identifiable, Sendable {
    let chainId: UInt64
    let chainName: String
    let symbol: String
    let decimals: Int
    let nativeBalance: BigUInt
    let tokens: [TokenBalance]

    var id: UInt64 { chainId }

    var nativeFormatted: String {
        UnitFormatter.formatWei(nativeBalance, decimals: UInt8(decimals))
    }
}

struct TokenBalance: Equatable, Identifiable, Sendable {
    let chainId: UInt64
    let contractAddress: String
    let symbol: String
    let name: String
    let decimals: UInt8
    let rawBalance: BigUInt

    var id: String { "\(chainId):\(contractAddress.lowercased())" }

    var formatted: String {
        UnitFormatter.formatWei(rawBalance, decimals: decimals)
    }
}
