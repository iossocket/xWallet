//
//  PaginatorDataSource.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public protocol PaginatorDataSource<Item>: Sendable {
    associatedtype Item: Sendable

    func fetchPage(
        key: String?,
        pageSize: Int
    ) async throws -> PaginatorPage<Item>
}
