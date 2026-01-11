//
//  EthereumRPC.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation

struct JsonRpcRequest: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: [String]
}

struct JsonRpcResponse: Decodable {
    let jsonrpc: String
    let id: Int
    let result: String?
    let error: JsonRpcError?
}

struct JsonRpcError: Decodable {
    let code: Int
    let message: String
}

enum EthereumRPCError: Error, CustomStringConvertible {
    case rpcError(Int, String)
    case invalidResponse
    case invalidHex

    var description: String {
        switch self {
        case .rpcError(let code, let message): return "RPC Error \(code): \(message)"
        case .invalidResponse: return "Invalid RPC response"
        case .invalidHex: return "Invalid hex string"
        }
    }
}

final class EthereumRPC {
    private let url: URL
    private let session: URLSession

    init(rpcURL: String, session: URLSession = .shared) {
        self.url = URL(string: rpcURL)!
        self.session = session
    }

    /// Returns balance in Wei as hex string, e.g. "0x..."
    func getBalanceWeiHex(address: String, block: String = "latest") async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = JsonRpcRequest(id: 1, method: "eth_getBalance", params: [address, block])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await session.data(for: request)
        let resp = try JSONDecoder().decode(JsonRpcResponse.self, from: data)

        if let err = resp.error {
            throw EthereumRPCError.rpcError(err.code, err.message)
        }
        guard let result = resp.result else {
            throw EthereumRPCError.invalidResponse
        }
        return result
    }

    /// Convenience: returns ETH (Decimal) from Wei hex.
    func getBalanceETH(address: String) async throws -> Decimal {
        let weiHex = try await getBalanceWeiHex(address: address)
        let wei = try parseHexToDecimal(weiHex)  // Wei as Decimal
        // 1 ETH = 10^18 Wei
        let eth = wei / Decimal(string: "1000000000000000000")!
        return eth
    }

    private func parseHexToDecimal(_ hex: String) throws -> Decimal {
        let clean = hex.lowercased().hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard !clean.isEmpty else { return 0 }

        var value = Decimal(0)
        for ch in clean {
            let digit: Int
            switch ch {
            case "0"..."9": digit = Int(ch.unicodeScalars.first!.value - Character("0").unicodeScalars.first!.value)
            case "a"..."f": digit = 10 + Int(ch.unicodeScalars.first!.value - Character("a").unicodeScalars.first!.value)
            default:
                throw EthereumRPCError.invalidHex
            }
            value = value * 16 + Decimal(digit)
        }
        return value
    }
}

