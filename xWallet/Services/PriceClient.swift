//
//  PriceClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 7/3/26.
//

import Dependencies
import Foundation
import ComposableArchitecture

// MARK: - TCA Dependency

@DependencyClient
struct PriceClient {
    var fetchPrices: @Sendable (String, [String]) async throws -> [String: Double]
}

extension PriceClient: DependencyKey {
    static var liveValue: PriceClient {
        let resolver: PriceIdResolverService = StaticPriceIdResolverService()
        let coinGecko = CoinGeckoPriceProvider(resolver: resolver, httpClient: AppHTTPClient.live)
        let defiLlama = DefiLlamaPriceProvider(resolver: resolver, httpClient: AppHTTPClient.live)
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
