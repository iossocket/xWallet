//
//  PaginatorError.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation

public enum PaginatorError: Error, Sendable, Equatable {
    case invalidKey
    case cancelled
    case network(String)
    case server(statusCode: Int)
    case store(String)
    case validationFailed
    case unknown(String)
}
