//
//  AppHTTPClientFactory.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

#if !DEBUG

import Foundation

enum _AppHTTPClientFactory {
    static func make() -> any HTTPClientProtocol {
        HTTPClient.shared
    }
}

#endif
