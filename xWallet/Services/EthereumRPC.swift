//
//  EthereumRPC.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation

final class EthereumRPC {
    private let url: URL
    private let session: URLSession
    private var nextId: Int = 1
    private let idLock = NSLock()

    init(rpcURL: String, session: URLSession = .shared) {
        self.url = URL(string: rpcURL)!
        self.session = session
    }

    // MARK: - Core JSON-RPC call

    func call<P: Encodable, R: Decodable>(
        method: String,
        params: P,
        timeout: TimeInterval = 30
    ) async throws -> R {
        let id = generateId()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = JsonRpcRequest(id: id, method: method, params: params)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard response is HTTPURLResponse else {
            throw EthereumRPCError.nonHTTPResponse
        }

        let decoded = try JSONDecoder().decode(JsonRpcResponse<R>.self, from: data)

        if let err = decoded.error {
            let details = err.data?.message.map { " (\($0))" } ?? ""
            throw EthereumRPCError.rpcError(err.code, err.message + details)
        }

        guard let result = decoded.result else {
            throw EthereumRPCError.invalidResponse
        }

        return result
    }

    /// Convenience for methods whose params are empty.
    func call<R: Decodable>(method: String) async throws -> R {
        try await call(method: method, params: EmptyParams())
    }

    private func generateId() -> Int {
        idLock.lock()
        defer { idLock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }
}

extension EthereumRPC {
    /// Returns balance in Wei as hex string, e.g. "0x..."
    func getBalanceWeiHex(address: String, block: String = "latest") async throws -> String {
        try await call(method: "eth_getBalance", params: [address, block])
    }

    /// Convenience: returns ETH (Decimal) from Wei hex.
    func getBalanceETH(address: String) async throws -> Decimal {
        let weiHex: String = try await getBalanceWeiHex(address: address)
        let wei = try parseHexToDecimal(weiHex)
        return wei / Decimal(string: "1000000000000000000")!
    }

    func getChainId() async throws -> Int {
        let hex: String = try await call(method: "eth_chainId")
        return try parseHexToInt(hex)
    }

    private func parseHexToInt(_ hex: String) throws -> Int {
        let clean = hex.lowercased().hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard let value = Int(clean, radix: 16) else { throw EthereumRPCError.invalidHex }
        return value
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
            default: throw EthereumRPCError.invalidHex
            }
            value = value * 16 + Decimal(digit)
        }
        return value
    }
}

struct EthCallObject: Encodable {
    let to: String
    let data: String
}

extension EthereumRPC {
    func ethCall(to: String, data: String, block: String = "latest") async throws -> String {
        let obj = EthCallObject(to: to, data: data)
        return try await call(method: "eth_call", params: [AnyEncodable(obj), AnyEncodable(block)])
    }
}


