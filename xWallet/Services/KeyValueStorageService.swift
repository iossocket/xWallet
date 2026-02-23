//
//  KeyValueStorageService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import Foundation
import Dependencies

struct KeyValueStorageClient {
    var save: @Sendable (String, String) -> Void
    var load: @Sendable (String) -> String?
}

extension KeyValueStorageClient: DependencyKey {
    static var liveValue: KeyValueStorageClient {
        KeyValueStorageClient(
            save: { value, key in UserDefaults.standard.set(value, forKey: key) },
            load: { key in UserDefaults.standard.string(forKey: key) }
        )
    }

    static var testValue: KeyValueStorageClient {
        KeyValueStorageClient(
            save: { _, _ in },
            load: { _ in nil }
        )
    }
}

extension DependencyValues {
    var keyValueStorage: KeyValueStorageClient {
        get { self[KeyValueStorageClient.self] }
        set { self[KeyValueStorageClient.self] = newValue }
    }
}
