//
//  Paginator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public protocol Paginator: Sendable {
    associatedtype Item: Sendable

    @discardableResult
    func fetch(
        key: String?,
        pageSize: Int,
        listener: @escaping @Sendable (Result<PaginatorPage<Item>, PaginatorError>) -> Void
    ) -> PaginatorExecution

    func clear(key: String?) async
    func clearAll() async
}
