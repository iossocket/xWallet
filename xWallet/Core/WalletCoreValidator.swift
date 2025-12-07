//
//  WalletCoreValidator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import Foundation
import WalletCore

struct WalletCoreValidator {
    /// 运行基础验证
    /// 在 App 启动时或 View 的 onAppear 中调用此方法
    static func runQuickCheck() {
        print("--------------- 🚀 WalletCore 验证开始 ---------------")
        
        // 1. 验证：尝试生成一个新的 HD 钱包 (12个助记词)
        // 这会测试底层的熵生成和 C++ 桥接是否正常
        guard let wallet = HDWallet(strength: 128, passphrase: "") else {
            print("无法创建 HDWallet 实例。WalletCore 可能未正确链接。")
            return
        }
        
        print("HDWallet 初始化成功")
        
        // 2. 验证：获取助记词
        // 确保字符串编码转换正常
        let mnemonic = wallet.mnemonic
        print("生成的助记词: \(mnemonic)")
        
        // 3. 验证：生成以太坊地址
        // 这会测试特定链的密钥派生逻辑 (BIP44)
        let ethAddress = wallet.getAddressForCoin(coin: .ethereum)
        print("派生的 ETH 地址: \(ethAddress)")
        
        // 4. 验证：生成比特币地址
        let btcAddress = wallet.getAddressForCoin(coin: .bitcoin)
        print("派生的 BTC 地址: \(btcAddress)")
        
        // 5. 验证：私钥生成
        // 获取 ETH 的私钥数据
        let ethPrivateKey = wallet.getKeyForCoin(coin: .ethereum)
        let ethPrivateKeyData = ethPrivateKey.data
        print("🔐 ETH 私钥长度: \(ethPrivateKeyData.count) bytes (预期 32)")
        
        if ethPrivateKeyData.count == 32 && !ethAddress.isEmpty {
            print("--------------- 🎉 验证通过：集成成功 ---------------")
        } else {
            print("--------------- ⚠️ 验证警告：数据似乎不完整 ---------------")
        }
    }
}
