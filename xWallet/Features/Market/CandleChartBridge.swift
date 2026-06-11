//
//  CandleChartBridge.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/3/26.
//

import SwiftUI
import UIKit

/// UIViewControllerRepresentable 桥接 — 把 UIKit 的 CandleChartViewController 嵌入 SwiftUI
///
/// 参考项目已有的 NewsFeedBridge.swift 模式：
///   SwiftUI TabView → CandleChartBridge → CandleChartViewController → MTKView
///
struct CandleChartBridge: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> CandleChartViewController {
        CandleChartViewController()
    }

    func updateUIViewController(
        _ uiViewController: CandleChartViewController,
        context: Context
    ) {
        // L0 暂无需要从 SwiftUI 传入的数据
        // L6 会在这里把 TCA state（candleData, indicators）传给 ViewController
    }
}
