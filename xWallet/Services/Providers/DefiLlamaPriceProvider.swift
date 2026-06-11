//
//  DefiLlamaPriceProvider.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

struct DefiLlamaPriceProvider: PriceProvider {
    let resolver: PriceIdResolverService
    let httpClient: any HTTPServiceProtocol

    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double] {
        let mapped = await resolver.resolve(chainId: chainId, symbols: symbols)
        guard !mapped.isEmpty else { return [:] }

        // DefiLlama uses "coingecko:" prefix for price IDs
        let prefixed = Set(mapped.values).map { "coingecko:\($0)" }.joined(separator: ",")
        guard let url = URL(string: "https://coins.llama.fi/prices/current/\(prefixed)") else {
            throw PriceError.invalidURL
        }

        let (data, response) = try await httpClient.data(for: URLRequest(url: url))
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
