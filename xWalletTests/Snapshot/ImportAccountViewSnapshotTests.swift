//
//  ImportAccountViewSnapshotTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 28/4/26.
//

import SnapshotTesting
import Testing
import ComposableArchitecture

@testable import xWallet

@MainActor
struct ImportAccountViewSnapshotTests {
    @Test
    func myViewController() {
        let view = ImportAccountView(
            store: Store(initialState: Account.State()) {
                Account()
            }
        )
        assertSnapshot(of: view, as: .image)
    }
}
