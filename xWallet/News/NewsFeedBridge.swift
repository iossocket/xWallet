//
//  NewsFeedBridge.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import UIKit
import SwiftUI

struct NewsFeedBridge: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> some UIViewController {
        return NewsFeedViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}
