## 1. 命令载体与类型基础

- [ ] 1.1 新建 `xWallet/Services/ChainOp.swift`：`ChainOp<R>`（struct + phantom `R` + `Kind` 数据载荷枚举）、10 条命令工厂（balance/transfer/metadata/nativeBalance/sendNative/estimateFee/waitForConfirmation + isDeployed(address:chain:)/estimateDeployFee/deploy）、`TokenMetadata` 轻量结构；将 `SendRequest`/`FeeEstimate`/`TxResult` 从 SendClient.swift 移入
- [ ] 1.2 `ContractArg` enum（.address/.uint256/.bool/.bytes）+ 到 `ABIValue`(EVM)/`CairoValue`(Starknet) 的映射（u256 拆 low/high、address→felt）
- [ ] 1.3 新建 `xWallet/Services/ChainClient.swift`：`ChainClient` struct + `execute<R>(_ op: ChainOp<R>) async throws -> R`、统一错误类型、`DependencyValues.chain` 注册、`testValue`（逐命令可 override、默认 unimplemented 报错）
- [ ] 1.4 app 侧 `extension StarknetAccount: DeployableAccount`（isDeployed 经 provider class hash 查询；classHash 取 accountType）

## 2. liveValue 运行时 dispatch

- [ ] 2.1 链解析 helper：token.chainId → 链/provider（EVM 数字 id 经 chainRegistry 查询；Starknet "SN_*" 短串 ↔ felt hex 匹配 registry，回退 presets）
- [ ] 2.2 合约组 `.balance`/`.transfer`/`.metadata`：`EthereumContract`/`StarknetContract` 薄包装（balanceOf/balance_of、transfer、name/symbol/decimals），不在 app 重造编解码
- [ ] 2.3 native 组 `.nativeBalance`/`.sendNative`：EVM eth_getBalance / plain value tx；Starknet STRK 合约读/写
- [ ] 2.4 `.estimateFee`/`.waitForConfirmation`：从 SendClient liveValue 移植（EVM prepareTransaction；Starknet nonce + estimateFee；两链等待收据 → TxResult）
- [ ] 2.5 部署组 `.isDeployed`/`.estimateDeployFee`/`.deploy`：从 StarknetRPCService 移植（getClassHashAt、deploy 估费、估费+签名+广播）
- [ ] 2.6 xcodebuild build 通过

## 3. reducer 迁移

- [ ] 3.1 `WalletClient` 增加 `activeAccount: (Chain) async throws -> any Account`；地址校验改为纯函数（Chain extension），调用方不再依赖 SendClient.validateAddress
- [ ] 3.2 `Send`：sendClient.* → `chain.execute(.estimateFee/.transfer/.sendNative/.waitForConfirmation)`；金额解析上移 reducer；删除 resolveChainAccount/`ChainAccount`
- [ ] 3.3 `AccountDeploy`：starknetRPCService.* → `.balance`(STRK)/`.estimateDeployFee`/`.deploy`/`.waitForConfirmation`
- [ ] 3.4 `Wallet` + `Account`：isAccountDeployed → `.isDeployed(address:chain:)`

## 4. 旧代码删除与收口

- [ ] 4.1 删除 `ERC20Client.swift`，grep 验证 `ERC20Client` 零引用
- [ ] 4.2 删除 `StarknetRPCService.swift`（命令已全部吸收）
- [ ] 4.3 删除 `SendClient.swift`（类型已移入 ChainOp.swift、validateAddress 已纯函数化）
- [ ] 4.4 `EvmBalanceProvider`/`StarknetBalanceProvider` 的合约读取改走 executor（`.balance`/`.nativeBalance`），删除重复 balance_of；不动 BalanceClient 编排
- [ ] 4.5 更新 `xWallet/Services/structure.md`（删除 SendClient/StarknetRPCService/ERC20Client 行，新增 ChainClient）

## 5. 测试与验证

- [ ] 5.1 新建 `xWalletTests/ChainClientTests.swift`：ContractArg 映射 + ChainOp 工厂返回类型单测
- [ ] 5.2 `SendTests` 改为 `\.chain` executor 命令 override
- [ ] 5.3 `AccountDeployTests` 改为 `\.chain` executor 命令 override
- [ ] 5.4 `WalletTests`/`AccountTests` 改为 `\.chain` executor 命令 override
- [ ] 5.5 xcodebuild test 全部通过
