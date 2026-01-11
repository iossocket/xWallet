//
//  Reducer.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation

public protocol Reducer {
    associatedtype State
    associatedtype Action
    
    @MainActor
    func reduce(into state: inout State, action: Action) -> Task<Void, Never>?
}
