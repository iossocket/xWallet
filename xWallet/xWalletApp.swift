//
//  xWalletApp.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/11/25.
//

import SwiftUI
import ComposableArchitecture
import Nuke

@main
struct xWalletApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    init() {
        let pipeline = ImagePipeline {
            $0.imageCache = ImageCache(costLimit: 100 * 1024 * 1024) // 100MB memory
            if let dataCache = try? DataCache(name: "com.xwallet.images") {
                dataCache.sizeLimit = 300 * 1024 * 1024 // 300MB disk
                $0.dataCache = dataCache
            }
            $0.isDecompressionEnabled = true
        }
        ImagePipeline.shared = pipeline
    }
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
