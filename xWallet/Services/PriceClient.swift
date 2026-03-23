//
//  PriceClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 7/3/26.
//

import Dependencies
import Foundation

// MARK: - TCA Dependency

struct PriceClient {
    var fetchPrices: @Sendable (String, [String]) async throws -> [String: Double]
}

extension PriceClient: DependencyKey {
    static var liveValue: PriceClient {
        live()
    }

    static var testValue: PriceClient {
        PriceClient(
            fetchPrices: { _, symbols in
                Dictionary(uniqueKeysWithValues: symbols.map { ($0, 1.0) })
            }
        )
    }
}

extension PriceClient {
    static func live(httpClient: any HTTPClientProtocol = AppHTTPClient.live) -> PriceClient {
        let resolver: PriceIdResolver = StaticPriceIdResolver()
        let coinGecko = CoinGeckoPriceProvider(resolver: resolver, httpClient: httpClient)
        let defiLlama = DefiLlamaPriceProvider(resolver: resolver, httpClient: httpClient)
        let repository = PriceRepository(coinGecko: coinGecko, defiLlama: defiLlama)

        return PriceClient(
            fetchPrices: { chainId, symbols in
                try await repository.fetchPrices(chainId: chainId, symbols: symbols)
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
