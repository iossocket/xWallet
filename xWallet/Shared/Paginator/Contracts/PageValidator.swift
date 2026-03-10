//
//  PageValidator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public protocol PageValidator<Item>: Sendable {
    associatedtype Item: Sendable
    func isValid(_ page: PaginatorPage<Item>) -> Bool
}
