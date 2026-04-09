## 1. 依赖配置

- [ ] 1.1 在 https://cloud.walletconnect.com 注册项目，获取 projectId
- [ ] 1.2 在 Xcode 中添加 SPM 依赖 `WalletConnectSwiftV2` (https://github.com/WalletConnect/WalletConnectSwiftV2)
- [ ] 1.3 在 `xWalletApp.swift` 的 `init()` 中配置 WalletConnect SDK（`Networking.configure(projectId:metadata:)`）

## 2. WalletConnectClient 实现

- [ ] 2.1 创建 `Services/WalletConnectClient.swift`，定义 `WCSession`、`SessionProposal`、`WCRequest`、`WCTransactionData` 模型
- [ ] 2.2 实现 `WalletConnectClient` struct，定义所有闭包签名（configure, pair, approveSession, rejectSession, approveRequest, rejectRequest, disconnect, activeSessions, sessionProposals, sessionRequests）
- [ ] 2.3 实现 `liveValue`：桥接 SDK 的 `Sign.wallet` 到闭包实现
- [ ] 2.4 实现 `sessionProposals()` AsyncStream：桥接 SDK 的 `sessionProposalPublisher` (Combine) 到 AsyncStream
- [ ] 2.5 实现 `sessionRequests()` AsyncStream：桥接 SDK 的 `sessionRequestPublisher` 到 AsyncStream，解析 request method 到 `WCRequest` enum
- [ ] 2.6 实现 `pair(uri:)`：调用 SDK 的 `Pair.instance.pair(uri:)`
- [ ] 2.7 实现 `approveSession(proposalId:chains:methods:)`：构造 SessionNamespace，调用 SDK 的 `Sign.wallet.approve`，返回 `WCSession`
- [ ] 2.8 实现 `rejectSession(proposalId:)`：调用 SDK 的 `Sign.wallet.reject`
- [ ] 2.9 实现 `approveRequest(topic:method:result:)`：调用 SDK 的 `Sign.wallet.respond`
- [ ] 2.10 实现 `rejectRequest(topic:reason:)`：调用 SDK 的 `Sign.wallet.respond` with error
- [ ] 2.11 实现 `disconnect(topic:)`：调用 SDK 的 `Sign.wallet.disconnect`
- [ ] 2.12 实现 `activeSessions()`：读取 SDK 的 `Sign.wallet.getSessions()`，转换为 `[WCSession]`
- [ ] 2.13 实现 `testValue`：所有闭包返回安全 stub（空数组、no-op、fatalError）
- [ ] 2.14 注册到 `DependencyValues`

## 3. DAppConnect Reducer 实现

- [ ] 3.1 创建 `Features/DApp/DAppConnect.swift`
- [ ] 3.2 定义 `State`：sessions, pendingProposal, pendingRequest, pairURI, isConnecting, errorMessage
- [ ] 3.3 定义 `Action`：binding, onAppear, pairTapped, pairResponse, sessionProposalReceived, approveProposalTapped, rejectProposalTapped, approveProposalResponse, requestReceived, approveRequestTapped, rejectRequestTapped, approveRequestResponse, disconnectTapped, disconnectResponse, refreshSessions
- [ ] 3.4 实现 `.onAppear`：加载 activeSessions，启动两个长期运行的 Effect 监听 sessionProposals 和 sessionRequests
- [ ] 3.5 实现 `.pairTapped`：验证 URI 非空，调用 `walletConnect.pair(uri)`
- [ ] 3.6 实现 `.pairResponse`：成功时清空 URI，失败时显示错误
- [ ] 3.7 实现 `.sessionProposalReceived`：保存到 `pendingProposal`
- [ ] 3.8 实现 `.approveProposalTapped`：调用 `walletClient.activeEvmAccount()` 和 `walletClient.activeStarknetAccount()` 获取地址，构造 accounts 数组（格式 "eip155:1:0x..."），调用 `walletConnect.approveSession`
- [ ] 3.9 实现 `.rejectProposalTapped`：调用 `walletConnect.rejectSession`，清空 `pendingProposal`
- [ ] 3.10 实现 `.approveProposalResponse`：成功时将 session 加入 `sessions` 列表
- [ ] 3.11 实现 `.requestReceived`：保存到 `pendingRequest`
- [ ] 3.12 实现 `.approveRequestTapped`：调用 `handleRequest` 辅助函数处理签名/交易，调用 `walletConnect.approveRequest` 返回结果
- [ ] 3.13 实现 `.rejectRequestTapped`：调用 `walletConnect.rejectRequest`，清空 `pendingRequest`
- [ ] 3.14 实现 `.disconnectTapped`：调用 `walletConnect.disconnect(topic)`
- [ ] 3.15 实现 `.disconnectResponse`：成功时触发 `.refreshSessions`
- [ ] 3.16 实现 `.refreshSessions`：重新加载 `activeSessions()`
- [ ] 3.17 实现 `handleRequest` 辅助函数：根据 `WCRequest` 类型分发到 personal_sign、eth_signTypedData、eth_sendTransaction、starknet_signTypedData 处理逻辑
- [ ] 3.18 实现 personal_sign 处理：调用 `walletClient.activeEvmAccount()`，调用 `account.signMessage(message)`
- [ ] 3.19 实现 eth_signTypedData 处理：调用 `account.signTypedData(data)`
- [ ] 3.20 实现 eth_sendTransaction 处理：调用 `account.sendTransaction(to:value:data:)`
- [ ] 3.21 实现 starknet_signTypedData 处理：调用 `walletClient.activeStarknetAccount()`，调用 `account.signTypedData(typedData:)` (Phase 1 基础实现)
- [ ] 3.22 定义 `WCError` enum：invalidAddress, unsupportedMethod

## 4. DAppConnectView 实现

- [ ] 4.1 创建 `Features/DApp/DAppConnectView.swift`
- [ ] 4.2 实现主视图结构：ScrollView + VStack，包含 connectSection 和 sessionsSection
- [ ] 4.3 实现 `connectSection`：标题 + TextField (pairURI) + 连接按钮，显示 errorMessage
- [ ] 4.4 实现 `sessionsSection`：ForEach 遍历 sessions，显示 sessionRow
- [ ] 4.5 实现 `sessionRow`：DApp 图标占位 + 名称 + URL + 断开按钮
- [ ] 4.6 实现 `.onAppear`：触发 `store.send(.onAppear)`
- [ ] 4.7 实现会话提案弹窗：`.sheet(isPresented:)` 绑定 `pendingProposal != nil`，显示 `proposalSheet`
- [ ] 4.8 实现 `proposalSheet`：显示 DApp 名称、URL、图标、请求连接文案、拒绝/连接按钮
- [ ] 4.9 实现签名请求弹窗：`.sheet(isPresented:)` 绑定 `pendingRequest != nil`，显示 `requestSheet`
- [ ] 4.10 实现 `requestSheet`：显示 "签名请求" 标题 + `requestDetail` + 拒绝/签名按钮
- [ ] 4.11 实现 `requestDetail`：根据 `WCRequest` 类型显示不同内容（personal_sign 显示消息文本，eth_signTypedData 显示结构化数据，eth_sendTransaction 显示交易详情）
- [ ] 4.12 应用设计系统：使用 `Color.xBg0/xBg2/xTextPrimary`、`Font.xTitle1/xBody/xMono`、`XSpacing.*`、`XRadius.*`

## 5. AppFeature 集成

- [ ] 5.1 在 `Features/App/AppFeature.swift` 的 `State` 中新增 `@Presents var dappConnect: DAppConnect.State?`
- [ ] 5.2 在 `Action` enum 中新增 `case dappConnect(PresentationAction<DAppConnect.Action>)`
- [ ] 5.3 在 `body` 中添加 `.ifLet(\.$dappConnect, action: \.dappConnect) { DAppConnect() }`
- [ ] 5.4 在 `Features/App/RootView.swift` 的 TabView 中新增 DApp Tab，显示 `DAppConnectView`
- [ ] 5.5 为 DApp Tab 设置图标（`Image(systemName: "link.circle.fill")`）和标签文本 "DApp"

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
- [ ] 6.13 测试 `.refreshSessions`：验证 `sessions` 列表更新

## 7. 文档和验收

- [ ] 7.1 在开发文档中记录 WalletConnect Cloud projectId 注册步骤
- [ ] 7.2 手动测试：使用 WalletConnect 测试 DApp (https://react-app.walletconnect.com) 验证配对流程
- [ ] 7.3 手动测试：验证 personal_sign 请求可以正常签名并返回
- [ ] 7.4 手动测试：验证 eth_sendTransaction 请求可以正常发送交易
- [ ] 7.5 手动测试：验证会话在 App 重启后保持连接
- [ ] 7.6 手动测试：验证断开会话功能正常工作
- [ ] 7.7 运行所有单元测试，确保通过
- [ ] 7.8 提交代码：`git commit -m "feat: add WalletConnect v2 DApp connection support"`
