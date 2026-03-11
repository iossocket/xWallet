//
//  PaginatorPage.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation

public final class PaginatorPage<Item: Sendable>: Sendable {
    public let content: [Item]
    public let key: String?
    public let expirationTime: Date?
    public let prevKey: String?
    public let nextKey: String?

    public init(
        content: [Item],
        key: String? = nil,
        expirationTime: Date? = nil,
        prevKey: String? = nil,
        nextKey: String? = nil
    ) {
        self.content = content
        self.key = key
        self.expirationTime = expirationTime
        self.prevKey = prevKey
        self.nextKey = nextKey
    }
}

extension PaginatorPage: Codable where Item: Codable {}
