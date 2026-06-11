//
//  HttpService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 8/6/26.
//

import ComposableArchitecture

@DependencyClient
struct HTTPService {
    var data: (_ for: URLRequest) async throws -> (Data, URLResponse)
}

extension HTTPService: DependencyKey {
    static var liveValue: Self {
        Self { urlRequest in
            try await AppHTTPClient.live.data(for: urlRequest)
        }
    }
}

extension DependencyValues {
    var httpService: HTTPService {
        get { self[HTTPService.self] }
        set { self[HTTPService.self] = newValue }
    }
}


@DependencyClient
struct SSLPinningHTTPService {
    var data: (_ for: URLRequest) async throws -> (Data, URLResponse)
}

extension SSLPinningHTTPService: DependencyKey {
    static var liveValue: Self {
        Self { urlRequest in
            let session = URLSession(
                configuration: .default,
                delegate: PinningSessionDelegate(),
                delegateQueue: nil
            )
            return try await session.data(for: urlRequest)
        }
    }
}

extension DependencyValues {
    var sslPinningHTTPService: SSLPinningHTTPService {
        get { self[SSLPinningHTTPService.self] }
        set { self[SSLPinningHTTPService.self] = newValue }
    }
}
