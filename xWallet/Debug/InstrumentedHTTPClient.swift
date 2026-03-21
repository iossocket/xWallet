//
//  InstrumentedHTTPClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

#if DEBUG

import Foundation

struct InstrumentedHTTPClient: HTTPClientProtocol {
    let base: any HTTPClientProtocol

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await base.data(for: request)
            XWNetworkMonitor.shared.record(
                request: request,
                response: response,
                responseBytes: data.count,
                error: nil,
                durationMs: (CFAbsoluteTimeGetCurrent() - start) * 1000
            )
            return (data, response)
        } catch {
            XWNetworkMonitor.shared.record(
                request: request,
                response: nil,
                responseBytes: nil,
                error: error,
                durationMs: (CFAbsoluteTimeGetCurrent() - start) * 1000
            )
            throw error
        }
    }
}

enum _AppHTTPClientFactory {
    static func make() -> any HTTPClientProtocol {
        InstrumentedHTTPClient(base: HTTPClient.shared)
    }
}

#endif
