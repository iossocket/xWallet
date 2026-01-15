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
    private var runningTasks: [AnyHashable: Task<Void, Never>] = [:]
    
    @Published private(set) var state: State
    
    private let reducer: R
    
    init(initialState: State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
    }
    
    func send(_ action: Action, cancelId: AnyHashable? = nil) {
        if let cancelId { runningTasks[cancelId]?.cancel() }
        if let task = reducer.reduce(into: &state, action: action, send: { newAction in
            self.send(newAction)
        }) {
            if let cancelId { runningTasks[cancelId] = task }
        }
    }
}
