//
//  KeyValueStorageService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import Foundation
import Dependencies

final class KeyValueStorageService {
    func save(value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func load(forKey key: String) -> String? {
        return UserDefaults.standard.string(forKey: key)
    }
}

extension KeyValueStorageService: DependencyKey {
    static var liveValue: KeyValueStorageService {
        KeyValueStorageService()
    }
}

extension DependencyValues {
    var keyValueStorage: KeyValueStorageService {
        get { self[KeyValueStorageService.self] }
        set { self[KeyValueStorageService.self] = newValue }
    }
}
