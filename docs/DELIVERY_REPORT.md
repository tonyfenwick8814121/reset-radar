# 0.1.0-preview 交付验证

验证日期：2026-09-09。源码提交以仓库 `main` 为准。

## 已通过

- `swift test -Xswiftc -warnings-as-errors`：23 项测试通过，覆盖 PT/PST 与夏令时歧义、相对时间锚点、RSS/Atom、HTML 登录页拒绝、重置券与自动重置分离、跨源去重、到点状态、通知节点、倒计时和存储备份恢复。
- 四个公开来源在无 X 登录、无 API 密钥条件下均读取成功：ModelYard 20 条、Codex Reset 40 条、OpenAI News 1180 条、OpenAI Status 80 条。数量只代表本轮订阅条目，不代表完整覆盖。
- 原生 UI 真机操作通过：首次居中、默认折叠、中/EN、展开详情、时区菜单、声音与音量、迷你窗、隐藏后进程继续、演示数据标记。
- 在 Chrome 独占全屏 Space 中，浮窗仍显示在页面上方；退出全屏后窗口状态正常。
- 最终 ZIP 从独立临时目录解压启动成功，运行路径确认来自解压后的应用；应用内再次完成四源查询。
- 最终 `.app` 与 ZIP 内应用逐文件一致，Info.plist、临时代码签名和 SHA-256 校验通过。
- GitHub Actions 在 `macos-26` 上通过 Swift 测试、Release 构建与包签名结构验证。

## 当前交付

- 本机安装：`/Applications/Reset Radar.app`
- Apple Silicon 测试包：`dist/Reset-Radar-0.1.0-preview-arm64.zip`
- 校验文件：`dist/Reset-Radar-0.1.0-preview-arm64.zip.sha256`
- 公开源码：[tonyfenwick8814121/reset-radar](https://github.com/tonyfenwick8814121/reset-radar)

## 尚未具备外部条件或长时间样本

- 当前没有 Developer ID 证书，应用是临时签名；本机可运行，但从互联网下载时 Gatekeeper 会拒绝。GitHub 暂不发布该未公证二进制。
- 尚未在 Intel Mac、外接多屏、Stage Manager 和完整睡眠 10 分钟场景上验证。
- 验证期间没有仍在未来的真实重置公告；真实抓取已验证，确定时间公告到倒计时使用合成夹具验证。遇到首条真实未来公告后应复核来源提前量和解析结果。
- 系统通知计划逻辑已自动化测试；没有为了 QA 主动触发通知授权弹窗或改变“登录时启动”的系统设置。
