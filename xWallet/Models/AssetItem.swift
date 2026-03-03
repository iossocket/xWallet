//
//  AssetItem.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI
import IdentifiedCollections

struct AssetItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let balance: String
    let value: String
    let change: String
    let icon: String
    let color: Color
}
