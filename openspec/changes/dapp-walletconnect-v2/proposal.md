## Why

xWallet 目前是一个独立钱包，无法与 DApp 交互。WalletConnect v2 是行业标准的钱包-DApp 连接协议，支持 EVM 和 Starknet，实现后用户可以在 DApp 中直接使用 xWallet 签名和发送交易。

## What Changes

- 新增 `WalletConnectClient` 依赖客户端，封装 WalletConnect Swift SDK 的配对、会话管理、请求处理
- 新增 `DAppConnect` TCA Reducer，管理会话列表、待处理提案、待处理签名请求的状态机
- 新增 `DAppConnectView`，提供 URI 输入/扫码入口、已连接会话列表、连接请求确认弹窗、签名请求确认弹窗
- 在 `AppFeature` 中新增 `DAppConnect` Reducer（`Scope` 组合，始终活跃），管理入口放在 Settings 的 NavigationLink，签名/提案弹窗挂在 ContentView 全局
- 在 `xWalletApp.swift` 初始化时配置 WalletConnect SDK（projectId + metadata）
- 新增 SPM 依赖 `WalletConnectSwiftV2`

## Capabilities

### New Capabilities

- `wc-session-management`: WalletConnect 会话的完整生命周期管理——配对、提案审批/拒绝、会话持久化、主动断开
- `dapp-request-signing`: 处理 DApp 发来的签名和交易请求——`personal_sign`、`eth_signTypedData_v4`、`eth_sendTransaction`，以及 Starknet 的 `starknet_signTypedData`

### Modified Capabilities

## Impact

- **新文件:** `Services/WalletConnectClient.swift`, `Features/DApp/DAppConnect.swift`, `Features/DApp/DAppConnectView.swift`
- **修改文件:** `xWalletApp.swift`（SDK 初始化）, `Features/App/AppFeature.swift`（新增 DAppConnect Scope）, `Features/App/ContentView.swift`（全局弹窗）, `Features/Settings/SettingsView.swift`（NavigationLink 入口）
- **新增 SPM 依赖:** `reown-swift` (github.com/reown-com/reown-swift)，product: `ReownWalletKit`
- **修改外部依赖:** `MultiChainKit` — 新增 `EIP712TypedData+Decodable`、`SNIP12TypedData+Decodable`、`Data+HexString` 三个工具方法
- **需要外部配置:** WalletConnect Cloud projectId（https://cloud.walletconnect.com）
- **测试:** 新增 `xWalletTests/DAppConnectTests.swift`
