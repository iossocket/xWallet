//
//  Mock.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation
@testable import xWallet

public struct MockItem: Sendable, Equatable, Codable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

final class MockDataSource: PaginatorDataSource, @unchecked Sendable {
    public init() {}
    
    private(set) var fetchCallCount = 0

    public func fetchPage(
        key: String?,
        pageSize: Int
    ) async throws -> PaginatorPage<MockItem> {
        self.fetchCallCount += 1
        
        let pageIndex = Int(key ?? "0") ?? 0
        let start = pageIndex * pageSize

        let items = (0..<pageSize).map {
            MockItem(id: start + $0, title: "Item \(start + $0)")
        }

        return PaginatorPage(
            content: items,
            key: key,
            expirationTime: Date().addingTimeInterval(60),
            prevKey: pageIndex > 0 ? "\(pageIndex - 1)" : nil,
            nextKey: "\(pageIndex + 1)"
        )
    }
}

struct ImmediateValidator<Item: Sendable>: PageValidator {
    func isValid(_ page: PaginatorPage<Item>) -> Bool {
        true
    }
}

struct AlwaysInvalidValidator<Item: Sendable>: PageValidator {
    func isValid(_ page: PaginatorPage<Item>) -> Bool {
        false
    }
}

actor MockStore: PaginatorStore {
    typealias Item = MockItem

    private var storage: [String: PaginatorPage<MockItem>] = [:]
    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0

    func load(key: String?) -> PaginatorPage<MockItem>? {
        loadCallCount += 1
        return storage[key ?? ""]
    }

    func save(key: String?, page: PaginatorPage<MockItem>) {
        saveCallCount += 1
        storage[key ?? ""] = page
    }

    func remove(key: String?) {
        storage.removeValue(forKey: key ?? "")
    }

    func removeAll() {
        storage.removeAll()
    }
}
