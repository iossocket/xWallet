//
//  ScopedStore.swift
//  xWallet
//
//  Created by Xueliang Zhu on 14/1/26.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class ScopedStore<ParentR: Reducer, ChildState, ChildAction>: ObservableObject {
    @Published private(set) var state: ChildState

    private let parent: Store<ParentR>
    private let toChildState: KeyPath<ParentR.State, ChildState>
    private let fromChildAction: (ChildAction) -> ParentR.Action

    private var cancellables: Set<AnyCancellable> = []

    init(
        parent: Store<ParentR>,
        state toChildState: KeyPath<ParentR.State, ChildState>,
        action fromChildAction: @escaping (ChildAction) -> ParentR.Action,
        removeDuplicates: ((ChildState, ChildState) -> Bool)? = nil
    ) {
        self.parent = parent
        self.toChildState = toChildState
        self.fromChildAction = fromChildAction
        self.state = parent.state[keyPath: toChildState]

        // parent state -> child state
        let publisher = parent.$state
            .map { $0[keyPath: toChildState] }

        if let removeDuplicates {
            publisher
                .removeDuplicates(by: removeDuplicates)
                .sink { [weak self] in self?.state = $0 }
                .store(in: &cancellables)
        } else {
            publisher
                .sink { [weak self] in self?.state = $0 }
                .store(in: &cancellables)
        }
    }

    func send(_ action: ChildAction) {
        parent.send(fromChildAction(action))
    }

    func binding<Value>(
        get: @escaping (ChildState) -> Value,
        send action: @escaping (Value) -> ChildAction
    ) -> Binding<Value> {
        Binding(
            get: { get(self.state) },
            set: { self.send(action($0)) }
        )
    }
}

extension Store {
    func scope<ChildState, ChildAction>(
        state toChildState: KeyPath<R.State, ChildState>,
        action fromChildAction: @escaping (ChildAction) -> R.Action
    ) -> ScopedStore<R, ChildState, ChildAction> {
        ScopedStore(parent: self, state: toChildState, action: fromChildAction)
    }

    func scope<ChildState: Equatable, ChildAction>(
        state toChildState: KeyPath<R.State, ChildState>,
        action fromChildAction: @escaping (ChildAction) -> R.Action
    ) -> ScopedStore<R, ChildState, ChildAction> {
        ScopedStore(
            parent: self,
            state: toChildState,
            action: fromChildAction,
            removeDuplicates: { $0 == $1 }
        )
    }
}


