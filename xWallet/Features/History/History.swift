//
//  History.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/3/26.
//

import ComposableArchitecture

@Reducer
struct History {
    @ObservableState
    struct State: Equatable {
        var address: String?
        var chain: Chain
        var errorMessage: String?
        var hasMore = true
        var isLoading = false
        var nextPageParams: [String: String]?
        var transactions: [HistoryTransaction] = []
    }

    enum Action {
        case historyResponse(Result<HistoryPage, Error>)
        case loadMore
        case onAppear
        case refresh
        case refreshResponse(Result<HistoryPage, Error>)
    }

    @Dependency(\.transactionHistory) var transactionHistory

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.transactions.isEmpty else { return .none }
                return fetchPage(state: &state)

            case .loadMore:
                guard !state.isLoading, state.hasMore else { return .none }
                return fetchPage(state: &state)

            case .historyResponse(.success(let page)):
                state.isLoading = false
                state.transactions.append(contentsOf: page.transactions)
                state.nextPageParams = page.nextPageParams
                state.hasMore = page.nextPageParams != nil
                return .none

            case .historyResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .refresh:
                guard let address = state.address else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let chain = state.chain
                return .run { [transactionHistory] send in
                    await send(.refreshResponse(
                        Result { try await transactionHistory.fetchHistory(address, chain, nil) }
                    ))
                }

            case .refreshResponse(.success(let page)):
                state.isLoading = false
                state.transactions = page.transactions
                state.nextPageParams = page.nextPageParams
                state.hasMore = page.nextPageParams != nil
                return .none

            case .refreshResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }

    private func fetchPage(state: inout State) -> Effect<Action> {
        guard let address = state.address else { return .none }
        state.isLoading = true
        state.errorMessage = nil
        let chain = state.chain
        let nextPageParams = state.nextPageParams
        return .run { [transactionHistory] send in
            await send(.historyResponse(
                Result { try await transactionHistory.fetchHistory(address, chain, nextPageParams) }
            ))
        }
    }
}
