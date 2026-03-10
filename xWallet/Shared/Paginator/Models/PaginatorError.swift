//
//  PaginatorError.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation

public enum PaginatorError: Error, Sendable {
    case invalidKey
    case cancelled
    case network(String)
    case store(String)
    case validationFailed
    case unknown(String)
}
