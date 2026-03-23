//
//  PriceRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

struct PriceRepository {
    private let coinGecko: CoinGeckoPriceProvider
    private let defiLlama: DefiLlamaPriceProvider
    private let cache: PriceCache

    init(coinGecko: CoinGeckoPriceProvider, defiLlama: DefiLlamaPriceProvider, cache: PriceCache = PriceCache()) {
        self.coinGecko = coinGecko
        self.defiLlama = defiLlama
        self.cache = cache
    }

    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double] {
        guard !symbols.isEmpty else { return [:] }

        // 协调：先查缓存
        let cacheKey = PriceCache.key(chainId: chainId, symbols: symbols)
        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        // 协调：Primary Provider (CoinGecko) → Fallback Provider (DefiLlama)
        let prices: [String: Double]
        do {
            prices = try await coinGecko.fetchPrices(chainId: chainId, symbols: symbols)
        } catch {
            prices = try await defiLlama.fetchPrices(chainId: chainId, symbols: symbols)
        }

        // 协调：写回缓存
        await cache.set(key: cacheKey, prices: prices)
        return prices
    }
}
