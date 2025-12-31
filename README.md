# xWallet

A modern, elegant cryptocurrency wallet app for iOS built with SwiftUI.

## Features

- 🎨 **Beautiful UI** - Modern design with aurora background effects and glassmorphism
- 💼 **Multi-Asset Support** - Manage multiple cryptocurrencies (ETH, BTC, USDT, SOL, DOGE, etc.)
- 🔐 **Secure Wallet** - Powered by WalletCore for secure key management
- 📊 **Portfolio Dashboard** - Visual ring progress indicator and asset overview
- 🚀 **Quick Actions** - Send, Receive, Swap, and Buy functionality
- 👁️ **Privacy** - Toggle balance visibility for enhanced privacy

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **WalletCore** (v4.4.2) - Blockchain wallet functionality
- **iOS 16.4+** - Minimum deployment target

## Project Structure

```
xWallet/
├── Core/
│   ├── Components/        # Reusable UI components
│   ├── Extensions/        # Swift extensions
│   └── WalletCoreValidator.swift
├── Features/
│   ├── Navigation/        # Floating tab bar
│   ├── Receive/           # Receive sheet view
│   └── Wallet/          # Wallet dashboard components
├── Models/
│   └── AssetItem.swift    # Asset data model
└── xWalletApp.swift       # App entry point
```

## Requirements

- Xcode 16.4+
- iOS 16.4+
- Swift 5.9+

## Getting Started

1. Clone the repository
2. Open `xWallet.xcodeproj` in Xcode
3. Build and run on a simulator or device

## Dependencies

- [WalletCore](https://github.com/trustwallet/wallet-core) - Blockchain wallet library
