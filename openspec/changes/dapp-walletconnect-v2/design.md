## Context

xWallet 当前是一个独立钱包应用，支持 EVM 多链和 Starknet，具备完整的钱包创建、导入、余额查询、转账功能。但用户无法将钱包连接到 DApp（如 Uniswap、OpenSea、Aave）进行交互。

WalletConnect v2 是行业标准的钱包-DApp 连接协议，通过 WebSocket 长连接实现实时通信，支持会话管理、签名请求、交易请求。官方 Swift SDK 已迁移到 `reown-swift`（WalletKit），原 `WalletConnectSwiftV2` 已废弃，新 SPM 地址为 `https://github.com/reown-com/reown-swift`，product 名为 `ReownWalletKit`。

经代码审计确认，MultiChainKit 已具备 WalletConnect 所需的全部签名能力：`EthereumAccount.signMessage` (EIP-191)、`EthereumAccount.signTypedData` (EIP-712)、`StarknetAccount.sign(feltHash:)` + `SNIP12TypedData.messageHash` (SNIP-12)。仅需补充三个胶水方法用于 JSON 反序列化和 hex 编码。

现有架构基于 TCA (The Composable Architecture)，所有副作用通过 `@Dependency` 客户端隔离，Reducer 纯函数处理状态转换。

## Goals / Non-Goals

**Goals:**
- 用户可以通过粘贴 URI 或扫码连接到 DApp
- 用户可以审批或拒绝 DApp 的连接请求
- 用户可以在钱包中确认 DApp 发来的签名请求（personal_sign、eth_signTypedData_v4）
- 用户可以在钱包中确认 DApp 发来的交易请求（eth_sendTransaction）
- 会话在 App 重启后保持连接
- 用户可以查看已连接的 DApp 列表并主动断开
- 支持 EVM 链的签名和交易请求
- 基础支持 Starknet 签名请求（starknet_signTypedData）

**Non-Goals:**
- 二维码扫描功能（Phase 2 实现，当前仅支持粘贴 URI）
- Starknet 交易请求的完整实现（starknet_execute，Phase 2 深度实现）
- 合约函数调用的 ABI 解码（Phase 2 优化）
- 多账户切换（当前仅支持活跃钱包的单一地址）
- 会话权限细粒度控制（如限制特定方法或链）

## Decisions

### Decision 1: 使用 WalletConnect Swift SDK 而非自行实现协议

**选择:** 依赖官方 `reown-swift`（WalletKit）SDK，SPM product `ReownWalletKit`，原 `WalletConnectSwiftV2` 已废弃迁移至此

**理由:**
- WalletConnect v2 协议复杂（WebSocket、加密、会话持久化、Relay 服务器交互）
- 官方 SDK 经过大量 DApp 和钱包的生产验证
- SDK 提供 Combine publisher（`sessionProposalPublisher`、`sessionRequestPublisher` 等），可桥接到 TCA 的 AsyncStream
- SDK 最低支持 iOS 13，与 xWallet 的 iOS 16.4 最低版本兼容
- 自行实现协议需要数周时间且容易出现兼容性问题

**替代方案:**
- 自行实现 WalletConnect v2 协议 — 拒绝，时间成本过高且风险大
- 使用 WalletConnect v1 — 拒绝，v1 已废弃且不支持 Starknet

**Trade-off:** SDK 增加约 5MB 包体积，但换来稳定性和开发效率

### Decision 2: WalletConnectClient 采用细粒度闭包模式

**选择:** `WalletConnectClient` 定义为包含多个闭包的 struct，而非返回 SDK 的 `Sign.wallet` 实例

**理由:**
- 与现有 `SendClient`、`StarknetProviderClient` 架构一致
- 每个闭包可独立 mock，测试时无需构造完整 SDK 实例
- 隔离 SDK 的 Combine publisher，统一转换为 AsyncStream 供 TCA 使用
- 避免 Reducer 直接依赖 WalletConnect SDK 类型

**替代方案:**
- 直接暴露 `Sign.wallet` — 拒绝，测试困难且 Reducer 与 SDK 耦合
- 使用 protocol — 拒绝，TCA 推荐 struct + closure 模式

### Decision 3: 会话提案和请求通过 AsyncStream 推送到 Reducer

**选择:** `WalletConnectClient` 提供 `sessionProposals()` 和 `sessionRequests()` 返回 AsyncStream，Reducer 在 `.onAppear` 中启动长期运行的 Effect 监听

**理由:**
- WalletConnect SDK 使用 Combine publisher 推送事件
- TCA 推荐用 AsyncStream 处理长期事件流
- Reducer 通过 `for await` 循环持续接收事件，符合 TCA 最佳实践

**实现细节:**
```swift
.run { [walletConnect] send in
    for await proposal in walletConnect.sessionProposals() {
        await send(.sessionProposalReceived(proposal))
    }
}
```

**替代方案:**
- 轮询检查新事件 — 拒绝，低效且不实时
- 使用 Combine publisher 直接在 Reducer 中 — 拒绝，TCA 不推荐在 Reducer 中使用 Combine

### Decision 4: 签名和交易请求的处理逻辑在 Reducer 中，调用现有 WalletClient

**选择:** `DAppConnect` Reducer 接收到请求后，调用 `walletClient.activeEvmAccount()` 或 `walletClient.activeStarknetAccount()` 获取账户，然后调用账户的签名/发送方法

**理由:**
- 复用现有 `WalletClient` 的账户管理逻辑（Keychain 读取、账户构造）
- 签名和交易逻辑已在 `Send` Reducer 中验证，直接复用
- 保持 `WalletConnectClient` 职责单一（仅处理 WalletConnect 协议层）

**替代方案:**
- 在 `WalletConnectClient` 中处理签名 — 拒绝，Client 不应访问 Keychain
- 创建独立的 `DAppSigningClient` — 拒绝，过度设计，现有 `WalletClient` 已足够

### Decision 5: DApp 管理入口在 Settings，状态在 AppFeature

**选择:** `DAppConnect` 状态始终存在于 `AppFeature.State` 中（非 `@Presents`），管理 UI 通过 Settings 的 NavigationLink 进入，签名/提案弹窗挂在 `ContentView` 层级

**理由:**
- DApp 连接是低频管理操作，不值得占一个独立 Tab
- 但 WalletConnect 事件（会话提案、签名请求）随时可能到达，AsyncStream 监听必须始终活跃
- 因此 reducer 状态放在 AppFeature（始终存在），入口放在 Settings（按需访问）
- 签名/提案确认弹窗挂在 ContentView 上，确保用户在任何 Tab 下都能收到

**架构分离:**
- `AppFeature.State.dappConnect: DAppConnect.State` — 始终存在，`Scope` 组合
- `Settings` 页面 — NavigationLink "DApp Connections" → `DAppConnectView`
- `ContentView` — `.sheet` 绑定 `pendingProposal` 和 `pendingRequest`，全局弹窗

**替代方案:**
- 独立 DApp Tab — 拒绝，低频操作不值得占 Tab 位，5 个 Tab 在小屏上拥挤
- `@Presents` 可选状态 — 拒绝，AsyncStream 监听必须始终活跃，不能等用户进入页面才创建

### Decision 6: 请求确认弹窗使用 SwiftUI .sheet，而非导航栈

**选择:** 会话提案和签名/交易请求通过 `.sheet(isPresented:)` 弹出模态窗口

**理由:**
- 请求可能在用户浏览任何 Tab 时到达，模态窗口可以覆盖当前界面
- 用户必须明确批准或拒绝，模态窗口强制用户做出决策
- 符合 iOS 权限请求的 UX 模式

**替代方案:**
- 使用 NavigationStack push — 拒绝，用户可能在其他 Tab，无法 push
- 使用系统 Alert — 拒绝，无法展示复杂内容（如 typed data 结构）

### Decision 7: EIP-712 / SNIP-12 JSON 解析放在 MultiChainKit 中

**选择:** 在 MultiChainKit 中为 `EIP712TypedData` 和 `SNIP12TypedData` 添加 `Decodable` 实现，同时为 `Data` 添加 `hexString` 扩展

**理由:**
- JSON 格式是行业标准（EIP-712 / SNIP-12），解析逻辑属于类型自身的能力
- `Decodable` 实现可被未来任何需要解析 typed data 的场景复用（不仅限于 WalletConnect）
- 避免 xWallet 中重复实现 JSON → typed data 的递归解析逻辑
- `Data.hexString` 用于将 `EthereumSignature.rawData` 转为 WalletConnect 需要的 `"0x..."` 格式

**新增内容（在 MultiChainKit 中）:**
1. `EIP712TypedData+Decodable.swift` — 解析标准 EIP-712 JSON（types, primaryType, domain, message）
2. `SNIP12TypedData+Decodable.swift` — 解析标准 SNIP-12 JSON（types, primaryType, domain, message）
3. `Data+Hex.swift` — `var hexString: String` 属性（`"0x" + bytes.map { String(format: "%02x", $0) }.joined()`）

**替代方案:**
- 放在 xWallet 的 `WalletConnectClient` 内部 — 拒绝，JSON 格式是标准规范，解析逻辑属于类型自身
- 手动构造而非反序列化 — 拒绝，DApp 发来的 JSON 需要通用解析

### Decision 8: 使用 reown-swift WalletKit API

**选择:** 使用 `WalletKit` 单例模式（`WalletKit.instance`）访问所有 API

**核心 API 映射:**
```swift
// 配置
WalletKit.configure(metadata: AppMetadata, crypto: DefaultCryptoProvider())

// 配对
WalletKit.instance.pair(uri: WalletConnectURI)

// 会话管理
WalletKit.instance.approve(proposalId: String, namespaces: [String: SessionNamespace]) -> Session
WalletKit.instance.rejectSession(proposalId: String, reason: RejectionReason)
WalletKit.instance.disconnect(topic: String)
WalletKit.instance.getSessions() -> [Session]

// 请求响应
WalletKit.instance.respond(topic: String, requestId: RPCID, response: RPCResult)
// RPCResult.response(AnyCodable) 用于批准, RPCResult.error(...) 用于拒绝

// Namespace 构建
AutoNamespaces.build(sessionProposal:chains:methods:events:accounts:) -> [String: SessionNamespace]

// 事件流 (Combine publishers → AsyncStream)
WalletKit.instance.sessionProposalPublisher  // (proposal: Session.Proposal, context: VerifyContext?)
WalletKit.instance.sessionRequestPublisher   // (request: Request, context: VerifyContext?)
WalletKit.instance.sessionDeletePublisher    // (String, Reason)
WalletKit.instance.sessionsPublisher         // [Session]
```

**请求参数解析:**
```swift
// personal_sign / eth_signTypedData — params 是 [String]
let params = try sessionRequest.params.get([String].self)

// eth_sendTransaction — params 是 [EthereumTransaction] (SDK 内置类型)
let params = try sessionRequest.params.get([EthereumTransaction].self)
```

## Risks / Trade-offs

**[Risk] WalletConnect Cloud projectId 未配置导致 SDK 初始化失败**
→ **Mitigation:** 在 `xWalletApp.init()` 中添加 `assert` 检查 projectId 非空，开发文档中明确说明注册步骤

**[Risk] SDK 的 Combine publisher 转 AsyncStream 可能丢失事件**
→ **Mitigation:** 使用 `AsyncStream` 的 buffering 策略，确保事件在 Reducer 处理前不会丢失

**[Risk] DApp 发来的 EIP-712 JSON 可能包含非标准嵌套结构**
→ **Mitigation:** `EIP712TypedData` 的 `Decodable` 实现根据 `types` 定义递归解析 `message` 字段值，对不识别的类型抛出明确错误而非静默失败。EIP-712 和 SNIP-12 均为行业标准 JSON 格式，主流 DApp 严格遵循规范

**[Risk] 用户在后台时收到请求，App 被系统挂起导致超时**
→ **Mitigation:** Phase 1 接受此限制，Phase 2 实现推送通知唤醒 App

**[Risk] DApp 发送恶意交易请求（如转走所有资产）**
→ **Mitigation:** 在确认弹窗中清晰展示交易详情（接收地址、金额、合约调用），用户需明确点击"确认"

**[Risk] 多个 DApp 同时发送请求导致 UI 混乱**
→ **Mitigation:** 请求队列化处理，一次只显示一个确认弹窗，其他请求排队等待

**[Risk] Starknet 账户未部署时签名请求可能失败**
→ **Mitigation:** 在确认弹窗中显示警告"账户未部署"，但允许用户继续（counterfactual 签名在某些场景下有效）

**[Trade-off] 当前仅支持粘贴 URI，不支持扫码**
→ 扫码需要相机权限和二维码解析库，Phase 1 优先实现核心流程，Phase 2 补充扫码功能

**[Trade-off] 合约调用无法解码显示函数名和参数**
→ 需要 ABI 数据库或链上查询，Phase 1 显示原始 hex data，Phase 2 优化用户体验

## Migration Plan

**部署步骤:**
1. 在 https://cloud.walletconnect.com 注册项目，获取 projectId
2. 在 Xcode 中添加 SPM 依赖 `reown-swift` (https://github.com/reown-com/reown-swift)，选择 `WalletKit` product
3. 在 `xWalletApp.swift` 的 `init()` 中调用 `WalletKit.configure(metadata:crypto:)` 并设置 projectId
4. 实现 `WalletConnectClient.liveValue`，桥接 SDK 的 Combine publisher 到 AsyncStream
5. 创建 `DAppConnect` Reducer 和 `DAppConnectView`
6. 在 `AppFeature` 中集成 DApp Tab
7. 运行测试，验证配对、会话管理、签名请求流程

**回滚策略:**
- 如果 WalletConnect 功能出现严重问题，可以在 `RootView` 中隐藏 DApp Tab
- 用户已连接的会话数据存储在 SDK 的本地数据库中，回滚不会丢失会话
- 重新部署修复版本后，会话自动恢复

**兼容性:**
- 最低 iOS 版本保持 16.4（WalletConnect SDK 支持 iOS 13+）
- 现有钱包功能（余额、转账、历史）不受影响
- 新增的 `WalletConnectClient` 依赖不会影响现有测试（testValue 提供安全 stub）

## Open Questions

1. **是否需要支持多账户切换？** 当前 `WalletClient` 返回单一活跃账户，如果用户有多个钱包身份，DApp 连接时应该暴露哪些地址？
   - **临时方案:** Phase 1 仅暴露当前活跃钱包的地址，Phase 2 支持用户选择要连接的账户

2. **Starknet 的 starknet_execute 请求如何估算 gas？** 当前 `SendClient` 已支持 Starknet 转账，但 DApp 可能发送任意合约调用
   - **临时方案:** Phase 1 使用 `StarknetAccount.estimateFee(calls:)` 估算，显示总费用，Phase 2 优化显示 L1/L2 gas 分解

3. **是否需要持久化会话权限设置？** 例如用户批准某个 DApp 后，下次自动批准相同请求
   - **决策:** Phase 1 不实现，每次请求都需要用户确认，Phase 2 考虑"信任此 DApp"选项

4. **如何处理 DApp 请求的链不在用户启用列表中？** 例如 DApp 请求 BSC，但用户禁用了 BSC
   - **决策:** 在会话提案确认弹窗中显示警告"某些链未启用"，允许用户部分批准（仅连接已启用的链）
