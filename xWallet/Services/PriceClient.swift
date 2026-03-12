//
//  PriceClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 7/3/26.
//

import Dependencies
import Foundation

// MARK: - Price ID Resolver

protocol PriceIdResolver: Sendable {
    /// Resolve a symbol on a given chain to an external price ID.
    /// Returns symbol → priceId mapping for all resolvable symbols.
    func resolve(chainId: String, symbols: [String]) async -> [String: String]
}

/// Static resolver using hardcoded mappings. Async interface for future extensibility.
struct StaticPriceIdResolver: PriceIdResolver {
    func resolve(chainId: String, symbols: [String]) async -> [String: String] {
        var mapped: [String: String] = [:]
        for symbol in symbols {
            if isNativeSymbol(symbol, chainId: chainId) {
                mapped[symbol] = nativePriceId(for: chainId)
            } else if let id = tokenPriceId(for: symbol) {
                mapped[symbol] = id
            }
        }
        return mapped
    }

    private func nativePriceId(for chainId: String) -> String {
        switch chainId {
        case "1", "11155111", "8453", "42161", "10": return "ethereum"
        case "137":        return "matic-network"
        case "56":         return "binancecoin"
        case "starknet":   return "starknet"   // Starknet 原生代币是 STRK
        default:           return "ethereum"
        }
    }

    private func tokenPriceId(for symbol: String) -> String? {
        switch symbol.uppercased() {
        case "USDC", "EURC": return "usd-coin"
        case "USDT":         return "tether"
        case "DAI":          return "dai"
        case "LINK":         return "chainlink"
        case "WETH":         return "weth"
        case "WBTC":         return "wrapped-bitcoin"
        case "ARB":          return "arbitrum"
        case "STRK":         return "starknet"
        default:             return nil
        }
    }

    private func isNativeSymbol(_ symbol: String, chainId: String) -> Bool {
        switch chainId {
        case "137":       return symbol.uppercased() == "MATIC"
        case "56":        return symbol.uppercased() == "BNB"
        case "starknet":  return symbol.uppercased() == "STRK"
        default:          return symbol.uppercased() == "ETH"
        }
    }
}

// MARK: - Provider Protocol

protocol PriceProvider: Sendable {
    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double]
}

// MARK: - CoinGecko Provider

struct CoinGeckoPriceProvider: PriceProvider {
    let resolver: PriceIdResolver

    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double] {
        let mapped = await resolver.resolve(chainId: chainId, symbols: symbols)
        guard !mapped.isEmpty else { return [:] }

        let uniqueIds = Array(Set(mapped.values))

        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")
        components?.queryItems = [
            URLQueryItem(name: "ids", value: uniqueIds.joined(separator: ",")),
            URLQueryItem(name: "vs_currencies", value: "usd"),
        ]
        guard let url = components?.url else { throw PriceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PriceError.httpError
        }

        let decoded = try JSONDecoder().decode([String: CoinGeckoPrice].self, from: data)

        var result: [String: Double] = [:]
        for (symbol, priceId) in mapped {
            if let price = decoded[priceId] {
                result[symbol] = price.usd
            }
        }
        return result
    }
}

private struct CoinGeckoPrice: Decodable {
    let usd: Double
}

// MARK: - DefiLlama Provider

struct DefiLlamaPriceProvider: PriceProvider {
    let resolver: PriceIdResolver

    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double] {
        let mapped = await resolver.resolve(chainId: chainId, symbols: symbols)
        guard !mapped.isEmpty else { return [:] }

        // DefiLlama uses "coingecko:" prefix for price IDs
        let prefixed = Set(mapped.values).map { "coingecko:\($0)" }.joined(separator: ",")
        guard let url = URL(string: "https://coins.llama.fi/prices/current/\(prefixed)") else {
            throw PriceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PriceError.httpError
        }

        let decoded = try JSONDecoder().decode(DefiLlamaResponse.self, from: data)

        var priceLookup: [String: Double] = [:]
        for (key, value) in decoded.coins {
            let id = key.hasPrefix("coingecko:") ? String(key.dropFirst(10)) : key
            priceLookup[id] = value.price
        }

        var result: [String: Double] = [:]
        for (symbol, priceId) in mapped {
            if let price = priceLookup[priceId] {
                result[symbol] = price
            }
        }
        return result
    }
}

private struct DefiLlamaResponse: Decodable {
    let coins: [String: DefiLlamaPrice]
}

private struct DefiLlamaPrice: Decodable {
    let price: Double
    let symbol: String?
    let confidence: Double?
}

// MARK: - TCA Dependency

struct PriceClient {
    var fetchPrices: @Sendable (String, [String]) async throws -> [String: Double]
}

extension PriceClient: DependencyKey {
    static var liveValue: PriceClient {
        let resolver: PriceIdResolver = StaticPriceIdResolver()
        let primary: PriceProvider = CoinGeckoPriceProvider(resolver: resolver)
        let fallback: PriceProvider = DefiLlamaPriceProvider(resolver: resolver)
        let cache = PriceCache()

        return PriceClient(
            fetchPrices: { chainId, symbols in
                guard !symbols.isEmpty else { return [:] }

                let cacheKey = PriceCache.key(chainId: chainId, symbols: symbols)
                if let cached = await cache.get(key: cacheKey) { return cached }

                let prices: [String: Double]
                do {
                    prices = try await primary.fetchPrices(chainId: chainId, symbols: symbols)
                } catch {
                    prices = try await fallback.fetchPrices(chainId: chainId, symbols: symbols)
                }

                await cache.set(key: cacheKey, prices: prices)
                return prices
            }
        )
    }

    static var testValue: PriceClient {
        PriceClient(
            fetchPrices: { _, symbols in
                Dictionary(uniqueKeysWithValues: symbols.map { ($0, 1.0) })
            }
        )
    }
}

extension DependencyValues {
    var priceClient: PriceClient {
        get { self[PriceClient.self] }
        set { self[PriceClient.self] = newValue }
    }
}

// MARK: - Errors

enum PriceError: Error {
    case invalidURL
    case httpError
}

// MARK: - Persistent Cache (UserDefaults)

private actor PriceCache {
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

        if let data = try? JSONEncoder().encode(prices) {
            defaults.set(data, forKey: dataKey)
        }
        defaults.set(Date(), forKey: tsKey)
    }
}
