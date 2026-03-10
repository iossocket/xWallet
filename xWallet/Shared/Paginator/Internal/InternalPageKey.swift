//
//  InternalPageKey.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

enum InternalPageKey: Hashable, Sendable {
    case initial
    case keyed(String)

    init(_ rawKey: String?) {
        if let rawKey, !rawKey.isEmpty {
            self = .keyed(rawKey)
        } else {
            self = .initial
        }
    }
}
