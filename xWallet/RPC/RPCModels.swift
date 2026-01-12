//
//  RPCModels.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/1/26.
//

import Foundation

/// JSON-RPC 2.0 request
struct JsonRpcRequest<P: Encodable>: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: P
}

/// JSON-RPC 2.0 response
struct JsonRpcResponse<R: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int
    let result: R?
    let error: JsonRpcError?
}

struct JsonRpcError: Decodable {
    let code: Int
    let message: String
    let data: JsonRpcErrorData?

    struct JsonRpcErrorData: Decodable {
        let message: String?
    }
}

enum EthereumRPCError: Error, CustomStringConvertible {
    case rpcError(Int, String)
    case invalidResponse
    case invalidHex
    case nonHTTPResponse

    var description: String {
        switch self {
        case .rpcError(let code, let message): return "RPC Error \(code): \(message)"
        case .invalidResponse: return "Invalid RPC response"
        case .invalidHex: return "Invalid hex string"
        case .nonHTTPResponse: return "Non-HTTP response"
        }
    }
}

struct EmptyParams: Encodable {
    init() {}
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
