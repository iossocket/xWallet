//
//  UnitFormater.swift
//  xWallet
//
//  Created by Xueliang Zhu on 2/3/26.
//

import BigInt

enum UnitFormatter {
    static func formatWei(_ wei: BigUInt, decimals: Int) -> String {
        guard wei > 0 else { return "0" }
        let divisor = BigUInt(10).power(Int(decimals))
        let whole = wei / divisor
        let remainder = wei % divisor
        guard remainder > 0 else { return whole.description }
        let padded = String(remainder).leftPadded(toLength: Int(decimals), with: "0")
        let frac = String(padded.prefix(6).reversed().drop(while: { $0 == "0" }).reversed())
        return frac.isEmpty ? whole.description : "\(whole).\(frac)"
    }
    
    static func parse(_ input: String, decimals: Int) -> BigUInt? {
        guard let bigUint = BigUInt(input, radix: 10) else {
            return nil
        }
        return bigUint * BigUInt(10).power(Int(decimals))
    }
}

private extension String {
    func leftPadded(toLength length: Int, with char: Character) -> String {
        guard count < length else { return self }
        return String(repeating: char, count: length - count) + self
    }
}
