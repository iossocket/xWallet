//
//  TransactionHistoryClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/3/26.
//

import BigInt
import ComposableArchitecture
import Foundation

// MARK: - Models

struct HistoryTransaction: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let hash: String
    let from: String
    let fromEns: String?
    let to: String
    let toEns: String?
    let value: String
    let symbol: String
    let timestamp: Date
    let isOutgoing: Bool
    let status: TxStatus
    let chainId: String
    let blockNumber: Int
    let method: String?

    enum TxStatus: String, Equatable, Hashable, Sendable {
        case success
        case failed
        case pending
    }
}

struct HistoryPage: Equatable, Sendable {
    let transactions: [HistoryTransaction]
    let nextPageParams: [String: String]?
}

// MARK: - Client

@DependencyClient
struct TransactionHistoryClient {
    var fetchHistory: @Sendable (
        _ address: String,
        _ chain: Chain,
        _ nextPageParams: [String: String]?
    ) async throws -> HistoryPage
}

extension TransactionHistoryClient: DependencyKey {
    static var liveValue: TransactionHistoryClient {
        return TransactionHistoryClient(
            fetchHistory: { address, chain, nextPageParams in
                guard let apiDomain = blockscoutDomain(forChainId: chain.chainId) else {
                    return HistoryPage(transactions: [], nextPageParams: nil)
                }
                var components = URLComponents(
                    string: "https://\(apiDomain)/api/v2/addresses/\(address)/transactions"
                )!

                if let params = nextPageParams {
                    components.queryItems = params.map {
                        URLQueryItem(name: $0.key, value: $0.value)
                    }
                }

                guard let requestURL = components.url else {
                    throw HistoryError.invalidURL
                }

                let (data, response) = try await AppHTTPClient.live.data(for: URLRequest(url: requestURL))
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw HistoryError.httpError
                }

                let decoded = try JSONDecoder().decode(BlockscoutResponse.self, from: data)
                let decimals = chain.decimals

                let transactions = decoded.items.map { tx in
                    HistoryTransaction(
                        id: tx.hash,
                        hash: tx.hash,
                        from: tx.from.hash,
                        fromEns: tx.from.ens_domain_name,
                        to: tx.to?.hash ?? "",
                        toEns: tx.to?.ens_domain_name,
                        value: formatWei(tx.value, decimals: decimals, symbol: chain.symbol),
                        symbol: chain.symbol,
                        timestamp: parseISO8601(tx.timestamp) ?? Date(),
                        isOutgoing: tx.from.hash.lowercased() == address.lowercased(),
                        status: tx.status == "ok" ? .success : .failed,
                        chainId: chain.chainId,
                        blockNumber: tx.block_number,
                        method: tx.method
                    )
                }

                return HistoryPage(
                    transactions: transactions,
                    nextPageParams: decoded.next_page_params
                )
            }
        )
    }
}

extension DependencyValues {
    var transactionHistory: TransactionHistoryClient {
        get { self[TransactionHistoryClient.self] }
        set { self[TransactionHistoryClient.self] = newValue }
    }
}

// MARK: - Blockscout API Response

private struct BlockscoutResponse: Decodable {
    let items: [BlockscoutTx]
    let next_page_params: [String: String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([BlockscoutTx].self, forKey: .items)

        // next_page_params values can be String, Int, or Double — normalize to [String: String]
        if let raw = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .next_page_params) {
            next_page_params = raw.mapValues { $0.stringValue }
        } else {
            next_page_params = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items, next_page_params
    }
}

/// Decodes mixed JSON values (string, number, bool) and converts to String.
private enum AnyCodableValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .string("") }
    }

    var stringValue: String {
        switch self {
        case .string(let v): return v
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .bool(let v): return String(v)
        }
    }
}

private struct BlockscoutTx: Decodable {
    let hash: String
    let from: AddressInfo
    let to: AddressInfo?
    let value: String
    let timestamp: String
    let status: String
    let block_number: Int
    let method: String?

    struct AddressInfo: Decodable {
        let hash: String
        let ens_domain_name: String?
    }
}

// MARK: - Helpers

/// Map EVM chainId to Blockscout API domain.
func blockscoutDomain(forChainId chainId: String) -> String? {
    switch chainId {
    case "1":          return "eth.blockscout.com"
    case "11155111":   return "eth-sepolia.blockscout.com"
    case "17000":      return "eth-holesky.blockscout.com"
    case "8453":       return "base.blockscout.com"
    case "84532":      return "base-sepolia.blockscout.com"
    case "137":        return "polygon.blockscout.com"
    case "42161":      return "arbitrum.blockscout.com"
    case "10":         return "optimism.blockscout.com"
    case "56":         return "bsc.blockscout.com"
    default:           return nil
    }
}

private func formatWei(_ weiStr: String, decimals: Int, symbol: String) -> String {
    guard let wei = BigUInt(weiStr), wei > 0 else { return "0 \(symbol)" }
    let formatted = UnitFormatter.formatWei(wei, decimals: decimals)
    return "\(formatted) \(symbol)"
}

private func parseISO8601(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string)
}

// MARK: - Errors

enum HistoryError: Error, Equatable {
    case invalidURL
    case httpError
}
