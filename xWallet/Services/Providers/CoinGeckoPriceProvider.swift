//
//  CoinGeckoPriceProvider.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

protocol PriceProvider: Sendable {
    func fetchPrices(chainId: String, symbols: [String]) async throws -> [String: Double]
}

struct CoinGeckoPriceProvider: PriceProvider {
    let resolver: PriceIdResolver
    let httpClient: any HTTPClientProtocol

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

        let (data, response) = try await httpClient.data(from: url)
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
