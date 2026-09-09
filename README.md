# 归零 · Reset Radar

设计 v2：默认免费公开订阅，免 X 登录和 API 密钥；折叠玻璃浮窗、浮窗内「中 / EN」、分状态色。

一款独立于 Codex 的 macOS 额度重置公告提醒器。关注公开预告，将明确的重置时间换算成本地时间，以悬浮窗倒计时提醒。

**当前交付：可运行的 macOS 原生预览版。** 已接入四个免费公开 RSS/Atom 来源，具备本地倒计时、浮窗/迷你窗、双语、时区、来源健康、持久化和本地通知基础能力。尚未签名公证或发布 GitHub Release。网页原型中的公告、查询结果和时间均为演示数据。

## 本机运行

要求 macOS 14 或更高版本，以及 Xcode 26 / Swift 6 工具链。无需 X 账号、API 密钥或付费服务。

```bash
git clone https://github.com/tonyfenwick8814121/reset-radar.git
cd reset-radar
swift test
./scripts/run.sh
```

构建后的应用位于 `dist/Reset Radar.app`。首次启动会显示在屏幕中央；关闭浮窗后可从菜单栏准星图标恢复。菜单中的“载入演示预告”只用于体验倒计时，窗口会持续显示“演示数据”。

## 数据与费用

应用每秒只在本地重算倒计时。社区订阅默认每 5 分钟检查，官方状态每 15 分钟、官方新闻每 30 分钟，并遵守服务端缓存。运行时不调用 OpenAI 模型，不消耗 ChatGPT/Codex 订阅额度。社区转引可能延迟、遗漏或分类错误，界面会把网络可达和上游覆盖分开表达。

- [PRD](docs/PRD.md)：产品范围、监测策略、窗口行为、提醒和文案。
- [Sol 开工说明](docs/START_HERE.md)：环境检查、首个交付切片与开发额度记录方式。
- [开发计划](docs/DEVELOPMENT_PLAN.md)：分阶段任务、依赖、验证与模型建议。
- [实现规格](docs/IMPLEMENTATION_SPEC.md)：数据结构、时间解析、调度、文件布局。
- [验收清单](docs/ACCEPTANCE.md)：可执行的场景和预期结果。
- [来源核查](docs/SOURCES.md)：2026-09-09 核查结果与尚未验证的条件。
- [交付验证](docs/DELIVERY_REPORT.md)：原生测试、真机操作、发布包和已知边界。
- [交互原型](design/prototype.html)：直接用浏览器打开，无需安装依赖。

开发阶段推荐 **Sol / high**；窗口跨桌面、时间歧义和提醒状态逻辑有疑难时，使用 **Astra / high** 定点解决。日常运行不调用任何模型，不占 ChatGPT/Codex 对话额度。

当前代码已完成 M0–M1 主链路并进入 M2/M3。原型表达外观和操作，不作为真实原生置顶、休眠唤醒或通知能力的验证。
