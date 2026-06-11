## Context

链操作（余额/转账/元数据/估费/等待/账户部署）当前在 app 里 per-chain 各写一遍：`EvmBalanceProvider`/`StarknetBalanceProvider` 各实现 `balanceOf`/`balance_of`；`SendClient` 内部 `switch account { .evm/.starknet }`；`StarknetRPCService` 负责账户部署并含一个与 BalanceProvider 重复的 `getBalance`；`ERC20Client` 是死代码。

SDK（MultiChainKit）已用 PAT 协议（`Provider<C>`/`Account<C>`/`DeployableAccount<C>`）抽象跨链，并已新增 `Contract<C>` 协议（`EthereumContract`/`StarknetContract` 均 conform，`read`/`readSingle<T>`/`write`，每链 `ABIValue.as(T)`/`CairoValue.as(T)` 解码）。但运行时统一仍缺一个 app 层。

约束：

- SDK `Contract<C>` 的 `Value` 是非 primary 关联类型 → `any Contract<C>` 隐藏 `Value`，**裸 existential 不能调 read/write**，运行时统一必须在 app 侧 dispatch 到具体 contract。
- SDK `Contract.write` 的 `value: BigUInt` 是 EVM-only（msg.value），Starknet 实现有意忽略（已在 SDK 文档 + 实现处注明）。
- SDK `Contract.write(account: some Account<C>)` 内部 `as?` 到具体 account，否则 throw `unsupportedAccount`；write 在 Account 层不可 mock，app 测试在命令层 stub。
- 本变更建在 `dependency-client-modernization` 已分层的 services 之上，应在其收尾后实施。

## Goals / Non-Goals

**Goals:**

- 上层 reducer 通过单一 executor + 命令菜单发起所有跨链操作，调用面跨链一致，不再 `switch chain` / `if native`。
- 链特定逻辑收敛到一处运行时 dispatch；加新链 = 加 dispatch 分支，不改调用方。
- 复用 SDK `Contract.read/write` + 每链解码，不重复造编解码；消除 balance_of/transfer 重复与死代码 `ERC20Client`。
- 命令携带返回类型，`execute<R> -> R` 调用点类型安全、无解包。

**Non-Goals:**

- 不在 SDK 层做运行时统一（PAT 是编译期；运行时桥在 app）。
- `ContractArg` 不做完整跨链 ABI，仅覆盖 fungible-token 公共子集。
- 不改 native token 语义（native 不是合约，单独命令）。
- 不重命名 `ERC20Token`；不动 UI `AssetItem`；portfolio 聚合 `BalanceClient` 重构列为后续阶段。

## Decisions

### D1: 命令式 executor（approach D）而非门面 client / token 对象 / 链句柄

**理由：** 在 A（链藏参数里的 client）/B（token 对象）/C（链句柄）/D（命令值 + 执行器）中选 D：所有跨链操作经单一 `execute<R>(_ op: ChainOp<R>) -> R` 收口，native 与各操作成为平级命令而非内部 `switch`/`if`，且批量/日志/重试可在 executor 一处加。**代价：** 调用多一层 `execute(.xxx(...))` 仪式感；菜单是会长大的清单。

### D2: `ChainOp<R>` 携带返回类型，`execute<R> -> R`

**理由：** 命令带 phantom `Response` 类型，调用点直接拿到正确类型，避免"enum 进 enum 出再 switch 解包"。`ChainOp` 内部表示（数据 + 解码闭包 vs 纯闭包）为实现细节，留待实现阶段定，对调用面无影响。

### D3: `ContractArg` 跨链入参，executor 映射到 SDK `Value`

**理由：** `ContractArg`（`.address/.uint256/.bool/.bytes`）映射到 `ABIValue`(EVM)/`CairoValue`(Starknet)，覆盖 ERC-20（balanceOf/transfer = address + uint256）。**Starknet u256 拆 low/high、address→felt 等链特定序列化在映射层处理。** Cairo enum/Option、EVM int(bits) 等富类型暂不进，需要时扩展或走链原生 `Value` 逃生舱。**备选：** 直接复用 SDK `ABIValue`/`CairoValue` 作为入参——被否，那样调用方又得知道链。

### D4: 部署能力靠参数类型 `any DeployableAccount` 编译期门控

**理由：** `.deploy`/`.estimateDeployFee` 收 `any DeployableAccount`（SDK 已有协议，`EthereumAccount` 非 deployable）。`execute(.deploy(evmAccount))` 直接编译不过，无需运行时"unsupported chain"判断，也无需拆两个 executor。**备选：** 单独 `StarknetOp` 命名空间——被否，两个入口更碎。

**实施修订（2026-06-10）：**
- `.isDeployed` 改为 `(address: String, chain: Chain) -> Bool` 只读查询，不收 account。原因：`Wallet`/`Account` 的部署状态检查只有地址；`StarknetAccount` 全部 init 都要私钥（Keychain 生物识别门控），开 app/切钱包时为状态检查弹 FaceID 是不可接受的回归。签名类命令（estimateDeployFee/deploy）保持 `any DeployableAccount` 门控。
- SDK 现状：`DeployableAccount` 协议已定义，但 **无任何类型 conform**（已读 SDK 源码确认）。在 app 侧加 `extension StarknetAccount: DeployableAccount`（retroactive conformance），不动 SDK，符合 D7。

### D5: native 为平级命令而非特例分支

**理由：** EVM native 不是合约（`eth_getBalance` + plain value tx），Starknet 无非合约 native（STRK/ETH 仍是合约）。把 native 做成 `.nativeBalance`/`.sendNative` 命令，调用方不再 `if native`；executor 内部按链实现（EVM 走 provider RPC，Starknet 走合约读）。

### D6: Token 复用 `ERC20Token`

**理由：** `ERC20Token`（chainId/address/symbol/decimals/name）已在 `ERC20TokenList` 服务两条链（含 Starknet STRK/ETH），字段满足命令需求，复用不新建类型。**已知瑕疵：** 名字 `ERC20` 却也装 Starknet token，改名 `FungibleToken` 列为后续。

### D7: executor 放 app（`xWallet/Services/`），不进 SDK

**理由：** 它编排 SDK 的 `Contract`/`Account`/`Provider`，属 app 的 Client 层；SDK 保持链原生、可独立复用。

**命名修订（2026-06-10）：** 类型命名为 `ChainClient`（原 `ChainExecutor`）。按 structure.md 分层对照，其职责（用例编排 + 签名/lifecycle，吸收的 `SendClient` 本就是 Client 层）落在 Client 层，且原则 1 要求"名字严格跟随层后缀，无例外"。"命令式 executor"仍是其 API 风格（D1），但不进类型名。keypath 不变：`@Dependency(\.chain)`。

## Risks / Trade-offs

- [ContractArg 覆盖面有限] → 仅公共子集；调非标准合约（NFT/swap/复杂入参）触界。**Mitigation:** 提供链原生 `Value` 逃生舱；按需扩展 `ContractArg`。
- [`ChainOp` 内部表示影响高级能力] → 纯闭包简单但不可检视；数据+解码闭包可日志/批量但更重。**Mitigation:** 调用面对两者无差，实现阶段再定，不阻塞本设计。
- [一次改动过大] → 同时引入 executor 并迁移 4 个 reducer + 删/改多个 client。**Mitigation:** 分阶段——先引入 executor + 命令并接 reducer 的直接 RPC 调用；portfolio 聚合重构作为后续阶段。
- [write 在 SDK Account 层不可 mock] → transfer/deploy 测试受限。**Mitigation:** 在 `ChainClient.testValue` 命令层 stub。
- [跨仓依赖] → SDK `Contract<C>` 在独立仓库。**Mitigation:** 已落地，仅需版本对齐。
- [错误类型不统一] → SDK 两链 `unsupportedAccount` 分属 `ContractError`/`CairoABIError`。**Mitigation:** executor 归一为单一 app 错误类型。

## Migration Plan

1. 引入 `ChainClient` + `ChainOp` + `ContractArg` + 命令菜单（`xWallet/Services/`），`@Dependency(\.chain)` 注册。
2. `.balance`/`.transfer`/`.metadata` 实现为 SDK `Contract` 薄包装；native/fee/wait/deploy 命令实现 dispatch。
3. 迁移 reducer 的直接 RPC 调用：
   - `AccountDeploy`：`starknetRPCService.*` → `.balance`/`.estimateDeployFee`/`.deploy`/`.waitForConfirmation`。
   - `Send`：`sendClient.*` → `.transfer`/`.sendNative`/`.estimateFee`/`.waitForConfirmation`。
   - `Wallet`/`Account`：`starknetRPCService.isAccountDeployed` → `.isDeployed`。
4. 删除 `ERC20Client`；收窄/删除 `StarknetRPCService`；balance providers 的合约读取收进 `.balance`。
5. 更新受影响的 reducer 测试为 `ChainClient.testValue` 命令 override。
6. （后续阶段）portfolio 聚合 `BalanceClient` 改用 `.batch([.balance...])`。

回滚：executor 与命令为新增；reducer 迁移可逐个回退到原 client 调用，因旧 client（除 ERC20Client）在迁移完成前保留。

## Open Questions

- ~~`ChainOp` 内部表示（数据 vs 闭包）~~——已定：**数据表示**（struct + phantom `R` + `Kind` 载荷枚举）。"Executor is testable per command" 要求 testValue 能按命令分支 stub，纯闭包不可检视，无法满足。
- ~~`.metadata` 返回类型~~——已定：新建轻量 `TokenMetadata`（name/symbol/decimals）。`.metadata(of: ERC20Token) -> ERC20Token` 进出同型语义混乱，且该命令当前零调用方，新类型无迁移成本。
- `BalanceClient`/portfolio 重构是否纳入本变更还是后续——倾向后续，避免一次改动过大。
