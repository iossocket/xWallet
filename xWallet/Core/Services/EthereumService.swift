//
//  EthereumService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/1/26.
//

import Foundation

enum Hex {
    static func decimalFromHex(_ hex: String) throws -> Decimal {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var result = Decimal(0)
        for char in clean {
            let value: Int
            switch char {
            case "0"..."9": value = Int(char.unicodeScalars.first!.value - 48)
            case "a"..."f": value = 10 + Int(char.unicodeScalars.first!.value - 97)
            default:
                throw NSError(domain: "hex", code: -1)
            }
            result = result * 16 + Decimal(value)
        }
        return result
    }
}

protocol EthereumServiceProtocol {
    var rpc: EthereumRPC { get }
}


struct EthereumService: EthereumServiceProtocol {
    let rpc: EthereumRPC
    
    init(rpc: EthereumRPC) {
        self.rpc = rpc
    }
    
    func getEthBalance(address: String) async throws -> Decimal {
        let hex = try await rpc.getBalanceWeiHex(address: address)
        let wei = try Hex.decimalFromHex(hex)
        return wei / Decimal(string: "1000000000000000000")!
    }
}
