//
//  Mock.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation
@testable import xWallet

public struct MockItem: Sendable, Equatable {
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
