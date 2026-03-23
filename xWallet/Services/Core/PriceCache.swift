//
//  PriceCache.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

actor PriceCache {
    private let defaults = UserDefaults.standard
    private let cachePrefix = "xwallet.price.cache."
    private let ttl: TimeInterval = 300 // 5 minutes

    static func key(chainId: String, symbols: [String]) -> String {
        "\(chainId):\(symbols.sorted().joined(separator: ","))"
    }

    func get(key: String) -> [String: Double]? {
        let tsKey = cachePrefix + key + ".ts"
        let dataKey = cachePrefix + key + ".data"

        guard let timestamp = defaults.object(forKey: tsKey) as? Date,
              Date().timeIntervalSince(timestamp) < ttl,
              let data = defaults.data(forKey: dataKey),
              let prices = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return nil }

        return prices
    }

    func set(key: String, prices: [String: Double]) {
        let tsKey = cachePrefix + key + ".ts"
        let dataKey = cachePrefix + key + ".data"

        defaults.set(Date(), forKey: tsKey)
        if let data = try? JSONEncoder().encode(prices) {
            defaults.set(data, forKey: dataKey)
        }
    }
}
