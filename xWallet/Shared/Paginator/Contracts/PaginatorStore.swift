//
//  PaginatorStore.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

public protocol PaginatorStore<Item>: Sendable {
    associatedtype Item: Sendable

    func load(key: String?) async throws -> PaginatorPage<Item>?
    func save(key: String?, page: PaginatorPage<Item>) async throws
    func remove(key: String?) async throws
    func removeAll() async throws
}
