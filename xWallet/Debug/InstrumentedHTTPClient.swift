//
//  InstrumentedHTTPClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

#if DEBUG

import Foundation

struct InstrumentedHTTPClient: HTTPServiceProtocol {
    let base: any HTTPServiceProtocol

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
    static func make() -> any HTTPServiceProtocol {
        InstrumentedHTTPClient(base: HTTPBaseService.shared)
    }
}

#endif
