//
//  TaskPaginatorExecution.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

public final class TaskPaginatorExecution: PaginatorExecution, @unchecked Sendable {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}
