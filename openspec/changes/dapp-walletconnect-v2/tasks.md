## 0. 前置：MultiChainKit 工具方法

- [ ] 0.1 在 `EthereumKit/Extensions/` 新增 `EIP712TypedData+Decodable.swift`：为 `EIP712TypedData` 实现 `Decodable`，根据 `types` 定义递归解析 `message` 中的 `EIP712Value`（string→.string, uint→.uint, address→.address, bytes→.bytes, struct→递归, array→递归）
- [ ] 0.2 在 `StarknetKit/Extensions/` 新增 `SNIP12TypedData+Decodable.swift`：为 `SNIP12TypedData` 实现 `Decodable`，根据 `types` 定义递归解析 `message` 中的 `SNIP12Value`（felt, u128, u256, ContractAddress, shortstring, bool, struct, array, enum）
- [ ] 0.3 在 `MultiChainCore/Extensions/` 新增 `Data+Hex.swift`：`extension Data { var hexString: String }` 返回 `"0x" + bytes hex`
- [ ] 0.4 为 0.1–0.3 编写单元测试，使用 EIP-712 / SNIP-12 标准测试向量验证

## 1. 依赖配置

- [ ] 1.1 在 https://cloud.walletconnect.com 注册项目，获取 projectId
- [ ] 1.2 在 Xcode 中添加 SPM 依赖 `reown-swift` (https://github.com/reown-com/reown-swift)，选择 product `ReownWalletKit`
- [ ] 1.3 在 `xWalletApp.swift` 的 `init()` 中配置 WalletKit SDK：
  ```swift
  let metadata = AppMetadata(
      name: "xWallet",
      description: "Multi-chain crypto wallet",
      url: "https://xwallet.app",
      icons: ["https://..."],
      redirect: AppMetadata.Redirect(native: "xwallet://", universal: nil)
  )
  WalletKit.configure(metadata: metadata, crypto: DefaultCryptoProvider())
  ```

## 2. WalletConnectClient 实现

- [ ] 2.1 创建 `Services/WalletConnectClient.swift`，定义桥接模型：
  - `WCSession`：封装 SDK 的 `Session`（topic, peerName, peerUrl, peerIcon, chains, methods）
  - `WCProposal`：封装 SDK 的 `Session.Proposal`（id, peerName, peerUrl, peerIcon, requiredChains, requiredMethods）
  - `WCRequest`：enum，cases = `.personalSign(message: Data, address: String)`, `.signTypedData(json: String, address: String)`, `.sendTransaction(tx: WCTransactionData)`, `.starknetSignTypedData(json: String)`, `.starknetExecute(calls: [WCStarknetCall])`
  - `WCTransactionData`：封装 eth_sendTransaction 参数（from, to, value, data, gasLimit, chainId）
- [ ] 2.2 定义 `WalletConnectClient` struct，闭包签名：
  ```swift
  struct WalletConnectClient {
      var pair: @Sendable (WalletConnectURI) async throws -> Void
      var approveSession: @Sendable (String, [String: SessionNamespace]) async throws -> WCSession
      var rejectSession: @Sendable (String, RejectionReason) async throws -> Void
      var approveRequest: @Sendable (String, RPCID, AnyCodable) async throws -> Void
      var rejectRequest: @Sendable (String, RPCID) async throws -> Void
      var disconnect: @Sendable (String) async throws -> Void
      var activeSessions: @Sendable () -> [WCSession]
      var sessionProposals: @Sendable () -> AsyncStream<WCProposal>
      var sessionRequests: @Sendable () -> AsyncStream<(WCRequest, String, RPCID)>
      var sessionDeleted: @Sendable () -> AsyncStream<String>
  }
  ```
- [ ] 2.3 实现 `liveValue`：
  - `pair`：调用 `WalletKit.instance.pair(uri:)`
  - `approveSession`：调用 `WalletKit.instance.approve(proposalId:namespaces:)`，转换返回的 `Session` 为 `WCSession`
  - `rejectSession`：调用 `WalletKit.instance.rejectSession(proposalId:reason:)`
  - `approveRequest`：调用 `WalletKit.instance.respond(topic:requestId:response: .response(result))`
  - `rejectRequest`：调用 `WalletKit.instance.respond(topic:requestId:response: .error(...))`
  - `disconnect`：调用 `WalletKit.instance.disconnect(topic:)`
  - `activeSessions`：调用 `WalletKit.instance.getSessions()`，转换为 `[WCSession]`
- [ ] 2.4 实现 `sessionProposals()` AsyncStream：
  ```swift
  AsyncStream { continuation in
      WalletKit.instance.sessionProposalPublisher
          .sink { (proposal, context) in
              continuation.yield(WCProposal(from: proposal, context: context))
          }
          .store(in: &cancellables)
  }
  ```
- [ ] 2.5 实现 `sessionRequests()` AsyncStream：桥接 `WalletKit.instance.sessionRequestPublisher`，解析 `request.method` 和 `request.params` 到 `WCRequest` enum：
  - `"personal_sign"` → `try request.params.get([String].self)` → `.personalSign`
  - `"eth_signTypedData_v4"` → `try request.params.get([String].self)` → `.signTypedData`
  - `"eth_sendTransaction"` → 解析 tx params → `.sendTransaction`
  - `"starknet_signTypedData"` → `.starknetSignTypedData`
  - `"starknet_execute"` → `.starknetExecute`
- [ ] 2.6 实现 `sessionDeleted()` AsyncStream：桥接 `WalletKit.instance.sessionDeletePublisher`
- [ ] 2.7 实现 `testValue`：所有闭包返回安全 stub（空数组、no-op、空 AsyncStream）
- [ ] 2.8 注册到 `DependencyValues`

## 3. DAppConnect Reducer 实现

- [ ] 3.1 创建 `Features/DApp/DAppConnect.swift`
- [ ] 3.2 定义 `State`：sessions: [WCSession], pendingProposal: WCProposal?, pendingRequest: (WCRequest, String, RPCID)?, pairURI: String, isConnecting: Bool, errorMessage: String?
- [ ] 3.3 定义 `Action`：binding, onAppear, pairTapped, pairResponse(Result), sessionProposalReceived(WCProposal), approveProposalTapped, rejectProposalTapped, approveProposalResponse(Result), requestReceived((WCRequest, String, RPCID)), approveRequestTapped, rejectRequestTapped, approveRequestResponse(Result), disconnectTapped(String), disconnectResponse(Result), sessionDeleted(String), refreshSessions
- [ ] 3.4 实现 `.onAppear`：加载 `activeSessions`，启动三个长期运行的 Effect 监听 `sessionProposals`、`sessionRequests`、`sessionDeleted`
- [ ] 3.5 实现 `.pairTapped`：验证 URI 非空，构造 `WalletConnectURI(string:)`，调用 `walletConnect.pair(uri)`
- [ ] 3.6 实现 `.pairResponse`：成功时清空 URI，失败时显示错误
- [ ] 3.7 实现 `.sessionProposalReceived`：保存到 `pendingProposal`
- [ ] 3.8 实现 `.approveProposalTapped`：
  - 调用 `walletClient.activeIdentitySet()` 获取活跃钱包地址
  - 使用 `AutoNamespaces.build(sessionProposal:chains:methods:events:accounts:)` 构造 namespaces
  - 调用 `walletConnect.approveSession(proposalId, namespaces)`
- [ ] 3.9 实现 `.rejectProposalTapped`：调用 `walletConnect.rejectSession(proposalId, .userRejected)`，清空 `pendingProposal`
- [ ] 3.10 实现 `.approveProposalResponse`：成功时将 session 加入 `sessions` 列表，清空 `pendingProposal`
- [ ] 3.11 实现 `.requestReceived`：保存到 `pendingRequest`
- [ ] 3.12 实现 `.approveRequestTapped`：根据 `WCRequest` 类型分发处理：
  - `.personalSign(message, addr)` → `walletClient.activeEvmAccount(provider)` → `account.signMessage(message)` → `"0x" + sig.rawData.hexString`
  - `.signTypedData(json, addr)` → JSON 解码为 `EIP712TypedData` → `account.signTypedData(typedData)` → hex 签名
  - `.sendTransaction(tx)` → `account.prepareTransaction(to:value:data:)` → `account.sign(tx:)` → `provider.send(raw:)` → txHash
  - `.starknetSignTypedData(json)` → JSON 解码为 `SNIP12TypedData` → `typedData.messageHash(accountAddress:)` → `account.sign(feltHash:)` → `[r.hexString, s.hexString]`
  - `.starknetExecute(calls)` → `account.executeV3(calls:)` → txHash
  - 调用 `walletConnect.approveRequest(topic, requestId, AnyCodable(result))`
- [ ] 3.13 实现 `.rejectRequestTapped`：调用 `walletConnect.rejectRequest(topic, requestId)`，清空 `pendingRequest`
- [ ] 3.14 实现 `.disconnectTapped(topic)`：调用 `walletConnect.disconnect(topic)`
- [ ] 3.15 实现 `.disconnectResponse`：成功时触发 `.refreshSessions`
- [ ] 3.16 实现 `.sessionDeleted(topic)`：从 `sessions` 中移除对应会话
- [ ] 3.17 实现 `.refreshSessions`：重新加载 `activeSessions()`

## 4. DAppConnectView 实现

- [ ] 4.1 创建 `Features/DApp/DAppConnectView.swift`
- [ ] 4.2 实现主视图结构：ScrollView + VStack，包含 connectSection 和 sessionsSection
- [ ] 4.3 实现 `connectSection`：标题 + TextField (pairURI) + 连接按钮，显示 errorMessage
- [ ] 4.4 实现 `sessionsSection`：ForEach 遍历 sessions，显示 sessionRow
- [ ] 4.5 实现 `sessionRow`：DApp 图标占位 + 名称 + URL + 断开按钮
- [ ] 4.6 实现 `.onAppear`：触发 `store.send(.onAppear)`
- [ ] 4.7 实现会话提案弹窗：`.sheet` 绑定 `pendingProposal != nil`，显示 `proposalSheet`
- [ ] 4.8 实现 `proposalSheet`：显示 DApp 名称、URL、图标、请求的链和方法、拒绝/连接按钮
- [ ] 4.9 实现签名请求弹窗：`.sheet` 绑定 `pendingRequest != nil`，显示 `requestSheet`
- [ ] 4.10 实现 `requestSheet`：显示 "签名请求" 标题 + `requestDetail` + 拒绝/签名按钮
- [ ] 4.11 实现 `requestDetail`：根据 `WCRequest` 类型显示不同内容（personal_sign 显示消息文本，eth_signTypedData 显示结构化数据预览，eth_sendTransaction 显示交易详情）
- [ ] 4.12 应用设计系统：使用 `Color.xBg0/xBg2/xTextPrimary`、`Font.xTitle1/xBody/xMono`、`XSpacing.*`、`XRadius.*`

## 5. AppFeature 集成

- [ ] 5.1 在 `Features/App/AppFeature.swift` 的 `State` 中新增 `dappConnect = DAppConnect.State()`
- [ ] 5.2 在 `Action` enum 中新增 `case dappConnect(DAppConnect.Action)`
- [ ] 5.3 在 `body` 中添加 `Scope(state: \.dappConnect, action: \.dappConnect) { DAppConnect() }`
- [ ] 5.4 在 `Features/Settings/SettingsView.swift` 中新增 NavigationLink "DApp Connections"，显示已连接会话数，导航到 `DAppConnectView`：
  ```swift
  NavigationLink {
      DAppConnectView(store: store.scope(state: \.dappConnect, action: \.dappConnect))
  } label: {
      Label("DApp Connections", systemImage: "link.circle.fill")
  }
  ```
  注：Settings 需要通过 AppFeature 传入 dappConnect 的 store scope（Settings.Action 新增 `case dappConnect(DAppConnect.Action)` 透传，或在 ContentView 层通过 SettingsView 初始化时传入 dappConnect store）
- [ ] 5.5 在 `Features/App/ContentView.swift` 上挂全局弹窗，绑定 `dappConnect.pendingProposal` 和 `dappConnect.pendingRequest`：
  ```swift
  .sheet(item: store.scope(state: \.dappConnect.pendingProposal, action: \.dappConnect)) { ... }
  .sheet(item: store.scope(state: \.dappConnect.pendingRequest, action: \.dappConnect)) { ... }
  ```
- [ ] 5.6 Tab enum 不变（wallet, market, discover, profile），不新增 DApp Tab

## 6. 测试

- [ ] 6.1 创建 `xWalletTests/DAppConnectTests.swift`
- [ ] 6.2 测试 `.pairTapped` with valid URI：验证 `isConnecting` 状态转换
- [ ] 6.3 测试 `.pairTapped` with empty URI：验证显示错误 "请输入或扫描 WalletConnect URI"
- [ ] 6.4 测试 `.pairResponse(.success)`：验证清空 `pairURI`，`isConnecting` 变为 false
- [ ] 6.5 测试 `.pairResponse(.failure)`：验证显示错误消息
- [ ] 6.6 测试 `.sessionProposalReceived`：验证 `pendingProposal` 被设置
- [ ] 6.7 测试 `.approveProposalTapped`：override `walletConnect.approveSession`，验证调用参数和 session 加入列表
- [ ] 6.8 测试 `.rejectProposalTapped`：验证 `pendingProposal` 被清空
- [ ] 6.9 测试 `.requestReceived`：验证 `pendingRequest` 被设置
- [ ] 6.10 测试 `.approveRequestTapped` with personal_sign：override `walletClient.activeEvmAccount`，验证签名流程
- [ ] 6.11 测试 `.rejectRequestTapped`：验证 `pendingRequest` 被清空
- [ ] 6.12 测试 `.disconnectTapped`：验证调用 `walletConnect.disconnect` 并触发 `.refreshSessions`
- [ ] 6.13 测试 `.sessionDeleted`：验证会话从列表中移除
- [ ] 6.14 测试 `.refreshSessions`：验证 `sessions` 列表更新

## 7. 文档和验收

- [ ] 7.1 在开发文档中记录 WalletConnect Cloud projectId 注册步骤
- [ ] 7.2 手动测试：使用 WalletConnect 测试 DApp (https://react-app.walletconnect.com) 验证配对流程
- [ ] 7.3 手动测试：验证 personal_sign 请求可以正常签名并返回
- [ ] 7.4 手动测试：验证 eth_sendTransaction 请求可以正常发送交易
- [ ] 7.5 手动测试：验证会话在 App 重启后保持连接
- [ ] 7.6 手动测试：验证断开会话功能正常工作
- [ ] 7.7 运行所有单元测试，确保通过
- [ ] 7.8 提交代码
