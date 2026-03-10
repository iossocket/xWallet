//
//  DefaultPageValidator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

import Foundation

public struct DefaultPageValidator<Item: Sendable>: PageValidator {
    public init() {}

    public func isValid(_ page: PaginatorPage<Item>) -> Bool {
        guard let expiration = page.expirationTime else { return true }
        return expiration > Date()
    }
}
