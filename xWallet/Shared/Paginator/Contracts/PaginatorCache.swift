//
//  PaginatorCache.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

public protocol PaginatorCache<Item>: Sendable {
    associatedtype Item: Sendable

    func value(for key: String?) async -> PaginatorPageResult<Item>?
    func set(_ value: PaginatorPageResult<Item>, for key: String?) async
    func remove(for key: String?) async
    func removeAll() async
}
