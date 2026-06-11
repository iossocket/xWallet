//
//  HTTPClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

import Foundation
import TrustKit

protocol HTTPServiceProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct HTTPBaseService: HTTPServiceProtocol {
    static let shared = HTTPBaseService()
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

enum AppHTTPClient {
    static var live: any HTTPServiceProtocol {
        _AppHTTPClientFactory.make()
    }
    static var sslLive: any HTTPServiceProtocol {
        SSLPinningHTTPBaseService()
    }
}

#if !DEBUG

enum _AppHTTPClientFactory {
    static func make() -> any HTTPServiceProtocol {
        return HTTPBaseService()
    }
    static var sslLive: any HTTPServiceProtocol {
        SSLPinningHTTPBaseService()
    }
}

#endif


struct SSLPinningHTTPBaseService: HTTPServiceProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let session = URLSession(
            configuration: .default,
            delegate: PinningSessionDelegate(),
            delegateQueue: nil
        )
        return try await session.data(for: request)
    }
}


final class PinningSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let handled = TrustKit.sharedInstance().pinningValidator.handle(
            challenge,
            completionHandler: completionHandler
        )
        
        if !handled {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
