//
//  PaginatorInMemoryCache.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public actor PaginatorInMemoryCache<Item: Sendable> {
    private var storage: [InternalPageKey: PaginatorPageResult<Item>] = [:]

    public init() {}

    func value(for key: InternalPageKey) -> PaginatorPageResult<Item>? {
        storage[key]
    }

    func set(_ value: PaginatorPageResult<Item>, for key: InternalPageKey) {
        storage[key] = value
    }

    func remove(for key: InternalPageKey) {
        storage.removeValue(forKey: key)
    }

    func removeAll() {
        storage.removeAll()
    }
}
