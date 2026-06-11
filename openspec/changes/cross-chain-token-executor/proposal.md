## Why

链操作（余额/转账/元数据/估费/等待/账户部署）目前在 app 里 per-chain 各写一遍，散落在 `EvmBalanceProvider`/`StarknetBalanceProvider`（balance_of 重复）、`SendClient`（内部 `switch account`）、`StarknetRPCService`（部署 + 与 BalanceProvider 重复的 getBalance）、以及死代码 `ERC20Client`。上层 reducer 因此被迫感知链差异。SDK（MultiChainKit）已提供链无关传输和 PAT 协议（`Provider<C>`/`Account<C>`/`DeployableAccount<C>`），并已新增 `Contract<C>` 协议，但**缺一个把这些统一成"一致调用面"的 app 层**。本变更引入单一 executor + 命令菜单，让跨链调用体验一致，并把链特定逻辑收敛到一处 dispatch。

## What Changes

- 新增 `ChainClient`（`@Dependency(\.chain)`，位于 `xWallet/Services/`），单一泛型方法 `execute<R>(_ op: ChainOp<R>) async throws -> R`。
- 新增 `ChainOp<R>` 带返回类型的命令 + 命令菜单（10 条：跨链组 7 + 部署门控组 3）。
- 新增 `ContractArg`（`.address/.uint256/.bool/.bytes`），executor 内部映射到 SDK `ABIValue`/`CairoValue`。
- `.balance`/`.transfer`/`.metadata` 实现为对 SDK `Contract.read/readSingle/write` 的薄包装；native 为平级命令；部署三件套靠参数 `any DeployableAccount` 编译期门控。
- **BREAKING（内部）** `SendClient` 的 `send/estimateFee/waitForConfirmation` 改为 executor 命令；`Send`/`AccountDeploy`/`Wallet`/`Account` reducer 改调 `chain.execute(...)`。
- **删除** `ERC20Client`（死代码，零调用方）。
- `StarknetRPCService` 溶解为命令（部署门控组 + `getBalance` → `.balance`），随后删除或收窄。
- `EvmBalanceProvider`/`StarknetBalanceProvider` 的 `balance_of` 收进 `.balance` 命令的合约 dispatch。
- Token 入参复用现有 `ERC20Token`（已服务两条链），不新建类型。

与 `dependency-client-modernization` 的关系：本变更**超越/取代**其中关于 `ERC20Client`、`StarknetRPCService`、`SendClient`、balance providers 的部分（那几个 ⚠️ 判断项的最终答案由本变更给出）。依赖：SDK `Contract<C>`（已实现）；建在 modernization 已分层的 services 之上，**应在 modernization 收尾后实施**。

## Capabilities

### New Capabilities

- `chain-client`: `ChainClient` DI 边界、`ChainOp<R>` 命令载体、`execute<R>` 方法、`ContractArg` 跨链入参映射、按链的运行时 dispatch（合约/native/部署三类）。
- `cross-chain-token-commands`: 统一命令菜单——跨链组（balance/transfer/metadata/nativeBalance/sendNative/estimateFee/waitForConfirmation）与能力门控组（isDeployed/estimateDeployFee/deploy），含其参数与 typed-result 契约。

### Modified Capabilities

<!-- 无已归档 openspec/specs/，故无 spec 级 Modified Capabilities。受影响的现有类型在 Impact 中列出。 -->

## Impact

- **新增代码**（`xWallet/Services/`）：`ChainClient`、`ChainOp`、`ContractArg` 及命令工厂。
- **删除**：`ERC20Client.swift`。
- **改写/收窄**：`SendClient`、`StarknetRPCService`、`EvmBalanceProvider`/`StarknetBalanceProvider` 的合约读取路径。
- **reducer 迁移**：`Send`、`AccountDeploy`、`Wallet`、`Account` 改用 `@Dependency(\.chain)`。
- **依赖**：SDK MultiChainKit 的 `Contract<C>`（独立仓库，已落地，需版本对齐）。
- **不受影响**：UI 层 `AssetItem`；native token 语义；portfolio 聚合 `BalanceClient` 的重构列为后续阶段。
- **测试**：`ChainClient.testValue` 逐命令 override；reducer 测试覆盖各命令分支。
