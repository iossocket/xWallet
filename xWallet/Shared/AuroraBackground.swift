//
//  AuroraBackground.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct AuroraBackground: View {
    var body: some View {
        Color(hex: "050505")
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.25))
                        .frame(width: 500, height: 500)
                        .blur(radius: 120)
                        .offset(x: -100, y: -250)
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
