//
//  HeaderView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct HeaderView: View {
    @Binding var showBalance: Bool
    let totalBalance: String
    
    var body: some View {
        HStack {
            // 左侧用户信息
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(white: 0.2), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: "person.fill")
                        .foregroundStyle(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL NET WORTH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .tracking(1)
                    
                    HStack(spacing: 6) {
                        Text(showBalance ? "$\(totalBalance)" : "****")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText()) // 数字滚动动画
                        
                        Image(systemName: showBalance ? "chevron.down" : "eye.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showBalance.toggle()
                        }
                    }
                }
            }
            
            Spacer()
            
            // 右侧设置按钮
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial) // 磨砂玻璃
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
}
