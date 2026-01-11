//
//  Store.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation
import Combine

@MainActor
final class Store<R: Reducer>: ObservableObject {
    typealias Action = R.Action
    typealias State = R.State
    @Published private(set) var state: State
    
    private let reducer: R
    
    init(initialState: State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
    }
    
    func send(_ action: Action) {
        _ = reducer.reduce(into: &state, action: action)
    }
}
