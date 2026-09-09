# 来源核查与证据边界

核查日期：2026-09-09，Asia/Shanghai。这里只证明来源和接口的部分事实，不代表已经运行全天监测，也不据此判断当前是否存在新的重置预告。

## 一手公告

1. [Tibo：向所有账户发放 banked reset](https://x.com/thsottiaux/status/2076735790567338203)。读取原帖页面标题及正文元数据成功，作者为 @thsottiaux。内容区分了发放可使用的机会与实际使用，可作用于周额度。产品因此需要单独的“有重置机会可使用”状态。
2. [Tibo：向 500k 用户发放 banked reset](https://x.com/thsottiaux/status/2076418567143408112)。读取页面标题成功，显示仅覆盖部分用户。不能推断当前用户获得了该机会。
3. [Tibo：宣布 ChatGPT Work 和 Codex 使用额度重置](https://x.com/thsottiaux/status/2075330198887940337)。页面标题描述已宣布重置、随后一小时传播。不能以抓取时间创建未来确定重置时点。

这些是历史事实样本；原帖链接可读不等于 X 用户时间线可稳定免费自动抓取。未在本次使用付费 X API 查询。

## 官方补充入口

- [OpenAI News RSS](https://openai.com/news/rss.xml)：HTTP 200，RSS XML，读取到新闻标题；可作为官方补充源，未证明覆盖所有额度公告。
- [OpenAI Status RSS](https://status.openai.com/history.rss)：HTTP 200，RSS XML，读取到服务事件；恢复公告本身不是额度恢复证据。
- [ChatGPT/Codex 额度与定价说明](https://learn.chatgpt.com/docs/pricing)：读取官方 Markdown 成功；页面指向 usage dashboard 查看当前限制与重置时间，也包含特定活动的 banked reset 规则。不能将活动的使用期限推广成所有重置机会的固定有效期。
- 官网更新日志及官方社区可提供线索；本次没有验证一个可靠覆盖临时重置公告的机器可读社区接口，不作为首版已接入来源。

社区检索帮助找到了历史原帖，产品事实以上述原帖为准。没有发现可据本次研究承诺“覆盖所有用户、所有临时重置”的统一官方公告 API；这属于本次未确认，不能表述成不存在。

## v2 免费接入核查（2026-09-09 补充）

本轮用不带 Cookie、Authorization 或 API 密钥的普通 HTTP 请求实测：

| 来源 | 实测响应 | 可用于产品的内容与限制 |
| --- | --- | --- |
| [ModelYard RSS](https://tibo.modelyard.dev/feed.xml) | 200，RSS，max-age=300，stale-while-revalidate=60 | 公开条目、原文片段和 X 原帖 URL；分类不是权威结论，转引银行式重置也可能被归成 Reset Planned |
| [Codex Reset Atom](https://codex-reset.com/feed.xml) | 200，Atom，max-age=300，stale-while-revalidate=300 | 历史事件与原帖链接；本次最新条目与同站 JSON 不一致，不保证覆盖全部实时预告 |
| [Codex Reset 公开 JSON](https://codex-reset.com/api/feed) | 200，JSON，max-age=60 | 包含 fetched_at、stale、tweets、原帖 URL；无用户密钥。列为未来可选补充，首版不要求配置接口 |
| [codexreset.app RSS](https://codexreset.app/feed.xml) | 200，RSS，max-age=300 | 混入预测、GitHub 活跃度、故障信号，不能整体当成已公布重置。本版不纳为主要预告源 |

社区主页有时对普通请求返回 403，但以上订阅是站点公开链接并可直接读取；不需要或尝试绕过主页访问限制。发现一个站点可读不代表建立了稳定的全渠道实时监测。

[Codex Reset 条款](https://codex-reset.com/terms)明确其为免费社区项目，并说明公告可能延迟、误分类或遗漏。它不是 OpenAI 官方服务。HTTP 200 与 feed 的 lastBuildDate/updated 也无法单独证明上游正常采集；发布时间与采集健康必须分开。

**设计决策：v2 默认纯 RSS/Atom 免费模式，不需要 X 账号、X API 或密钥，取消付费直连的首版前置条件。** 没有自建云服务、模型调用或 API 账单；第三方未来可能停止或改变服务，届时降级并显示不可用，不能自动转收费路径。

先前研究的 [X 应用认证](https://docs.x.com/fundamentals/authentication/oauth-2-0/application-only)、[时间线](https://docs.x.com/x-api/posts/timelines/introduction)和[付费规则](https://docs.x.com/x-api/getting-started/pricing)仅作为将来用户主动要求直连 X 时的参考，不再是当前开发依赖。上一版按帖子数量估算的费用不适用于 v2 免费订阅模式。

## macOS 玻璃效果与模型

- [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview)：已读官方 Markdown，availability 标记 macOS 26.0+。SwiftUI glassEffect 的官方元数据也标记 macOS 26.0+；本版在旧系统用 NSVisualEffectView 回退。网页 CSS 只模拟视觉，不是原生系统效果。
- [AppKit canJoinAllSpaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)：读取官方 Markdown，支持窗口出现在各 Spaces。
- [AppKit fullScreenAuxiliary](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)：读取官方 Markdown，支持与全屏窗口同 Space；跨其他应用全屏、Stage Manager 和焦点行为仍需真机验证。
- [OpenAI 模型比较](https://developers.openai.com/api/docs/models/compare)：已打开官方页，比较 Astra、Sol 的定位与 API 定价；此信息不能直接映射成订阅的额度倍率。
- [Astra 官方指南](https://developers.openai.com/api/docs/guides/latest-model)：已打开，强调复杂多步骤任务能力；有时更少的输出可抵消较高单价，因此模型选择需按实际任务判断。

“Sol/high 主开发、Astra/high 定点处理难题”是本项目决策，不是官方关于此应用的基准结论。
