//
//  AuroraBackground.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct AuroraBackground: View {
    var body: some View {
        // 修改：使用 Color 作为主视图，将光晕作为 overlay 添加
        // 这样视图的尺寸由 Color (充满屏幕) 决定，而不是由巨大的 Circle 决定
        Color(hex: "050505")
            .overlay {
                ZStack {
                    // 顶部蓝光
                    Circle()
                        .fill(Color.blue.opacity(0.25))
                        .frame(width: 500, height: 500) // 即使这里是 500，也不会撑大父视图
                        .blur(radius: 120)
                        .offset(x: -100, y: -250)
                    
                    // 底部紫光
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .offset(x: 150, y: 300)
                }
            }
            .ignoresSafeArea()
    }
}
