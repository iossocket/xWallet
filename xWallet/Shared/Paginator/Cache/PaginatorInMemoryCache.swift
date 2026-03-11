//
//  PaginatorInMemoryCache.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public actor PaginatorInMemoryCache<Item: Sendable>: PaginatorCache {
    private var storage: [InternalPageKey: PaginatorPageResult<Item>] = [:]

    public init() {}

    public func value(for key: String?) -> PaginatorPageResult<Item>? {
        storage[InternalPageKey(key)]
    }

    public func set(_ value: PaginatorPageResult<Item>, for key: String?) {
        storage[InternalPageKey(key)] = value
    }

    public func remove(for key: String?) {
        storage.removeValue(forKey: InternalPageKey(key))
    }

    public func removeAll() {
        storage.removeAll()
    }
}
