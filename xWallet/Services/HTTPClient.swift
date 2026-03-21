//
//  HTTPClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

import Foundation

protocol HTTPClientProtocol: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

enum AppHTTPClient {
    static var live: any HTTPClientProtocol {
        _AppHTTPClientFactory.make()
    }
}

struct HTTPClient: HTTPClientProtocol {
    static let shared = HTTPClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
