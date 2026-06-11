# analyze_trace.py

从 Xcode Instruments `.trace` 文件中提取 Heaviest Stack Trace，输出与 Instruments Time Profiler 一致的加权调用树分析。

## 前置条件

- macOS，已安装 Xcode（需要 `xctrace` 命令行工具）
- Python 3.9+
- 一个 `.trace` 文件（通过 Instruments 录制生成）

## 符号化（推荐）

导出前先符号化，否则 app 自身代码会显示为 `0x...` 地址：

```bash
xctrace symbolicate --input MyApp.trace
```

符号化需要对应的 dSYM 文件。Debug 构建通常自动可用；Release/Archive 构建需确保 dSYM 在 Spotlight 索引路径下（如 `~/Library/Developer/Xcode/Archives/`）。

## 用法

```bash
# 基础用法（自动从文件名推断 app 关键词）
python3 analyze_trace.py xWallet01.trace

# 指定关键词，高亮 app 自身代码（★ 标记）
python3 analyze_trace.py xWallet01.trace --app-keywords "xWallet,Cell,ViewController"

# 只分析主线程
python3 analyze_trace.py xWallet01.trace --thread "Main Thread"

# 组合使用
python3 analyze_trace.py xWallet01.trace --thread "Main Thread" --app-keywords "xWallet,News,Cell"
```

## 参数说明

| 参数 | 必填 | 说明 |
|------|------|------|
| `trace` | 是 | `.trace` 文件路径 |
| `--thread` | 否 | 过滤特定线程，如 `"Main Thread"`。默认显示主线程 + 全线程 |
| `--app-keywords` | 否 | 逗号分隔的关键词，匹配到的帧标记 ★。默认从文件名推断 |

## 输出说明

脚本输出 4 个部分：

### 1. Thread Weight Distribution

各线程的 CPU 采样权重占比，快速定位哪个线程最忙。

```
  4940.0 ms ( 56.3%) | Main Thread
   506.0 ms (  5.8%) | com.apple.UIKit.inProcessAnimationManager
```

### 2. Hottest Functions (self time)

叶子帧（调用栈顶端）的累计时间，即函数自身执行耗时，不含子调用。

```
   506.0 ms (  5.8%) objc_msgSend
   154.0 ms (  1.8%) _xzm_xzone_malloc_tiny
```

### 3. Heaviest Stack Trace

与 Instruments "Heaviest Stack Trace" 视图一致：从调用树根节点开始，每一层选择权重最大的子节点，形成一条最重路径。`★` 标记匹配 `--app-keywords` 的 app 自身代码。

```
  4316.0 ms ( 87.4%)   start
  4263.0 ms ( 86.3%)     static App.main()
   233.0 ms (  4.7%) ★                 CompactNewsCell.configure(with:)
```

### 4. App Frames (inclusive weight)

所有匹配 app 关键词的帧按 inclusive time（出现在调用栈中任意位置的累计时间）排序，帮助快速定位 app 代码中最耗时的函数。

```
   233.0 ms (  4.7%) CompactNewsCell.configure(with:)
   127.0 ms (  2.6%) CompactNewsCell.configureTags(_:)
    80.0 ms (  1.6%) CompactNewsCell.prepareForReuse()
```

## 典型工作流

```bash
# 1. 在 Instruments 中录制 Time Profiler trace

# 2. 符号化
xctrace symbolicate --input xWallet01.trace

# 3. 分析
python3 analyze_trace.py xWallet01.trace --app-keywords "xWallet,Cell,News"

# 4. 根据输出定位性能瓶颈，修复后重新录制对比
```
