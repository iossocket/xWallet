//
//  PaginatorPageResult.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation

public enum PaginatorPageResult<Item: Sendable>: Sendable {
    case idle
    case loading
    case success(PaginatorPage<Item>)
    case failure(PaginatorError)
}
