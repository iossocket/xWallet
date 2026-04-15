//
//  AppConfiguration.swift
//  xWallet
//
//  Created by Xueliang Zhu on 15/4/26.
//

import Nuke

enum AppConfiguration {
    static func setup() {
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
}
