# 模拟股神

一款 iOS 股票模拟交易游戏。真实行情、虚拟资金、多种难度模式。

## 特性

- **真实行情**：A股 / 港股 / 美股，实时报价与日K走势
- **多种模式**：从 ¥1,000 地狱开局到无限资产，五种难度
- **模拟交易**：市价买卖、持仓成本、浮动盈亏、账户总览
- **零依赖**：纯 SwiftUI，不使用任何第三方库

## 技术栈

| 项 | 选择 |
|---|---|
| UI | SwiftUI（iOS 16+） |
| 图表 | Swift Charts |
| 工程 | XcodeGen（`project.yml`） |
| 持久化 | UserDefaults + Codable |
| 构建 | GitHub Actions · macos-15 · Xcode 16.4 |

## 行情数据源

腾讯财经公开接口（HTTPS，GBK 编码）：

| 用途 | 接口 |
|---|---|
| 实时行情 | `https://qt.gtimg.cn/q=sh600000,hk00700,usAAPL` |
| 日K线 | `https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?param=<code>,day,,,60,qfq` |
| 搜索 | `https://smartbox.gtimg.cn/s3/?q=<关键词>&t=all` |

> 仅供学习娱乐使用，行情数据版权归腾讯财经所有，不构成任何投资建议。

## 本地开发

仓库不含 `.xcodeproj`（由 XcodeGen 生成）：

```bash
brew install xcodegen
xcodegen generate
open MockStock.xcodeproj
```

## 打包 ipa

推送到 `main` 分支自动触发 GitHub Actions，产出未签名 IPA。
产物在 Actions 的 Artifacts 或 Releases 页面下载。

## 安装

未签名 IPA 不能直接安装，需用 [Sideloadly](https://sideloadly.io) + 免费 Apple ID 重签：

1. USB 连接 iPhone，信任此电脑
2. 把 `.ipa` 拖进 Sideloadly，填入 Apple ID，点 Start
3. 手机上：设置 → 通用 → VPN与设备管理 → 信任描述文件
4. **7 天后失效**，重签一次即可（数据保留）

免费 Apple ID 限制：有效期 7 天、最多 3 个自签 App。
