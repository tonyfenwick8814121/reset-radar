# 实现规格

本文件是待开发契约，命名可按 Swift 惯例调整，用户可见行为遵守 PRD。

## 数据模型

`ResetEvent` 字段：

| 字段 | 类型/约束 |
| --- | --- |
| id / revision | 稳定事件 ID / 单调递增整数；更正原事件，不新建重复事件 |
| kind | `automatic_reset / banked_reset_grant / limit_change / lead` |
| products / limitWindows | 数组；明确区分 chatgpt、chatgpt_work、codex、unknown；weekly、five_hour、other、unknown |
| audience | 范围 all/partial/unknown、套餐数组、原始条件文字；不存个人账户身份 |
| state | `unresolved / scheduled / due_unconfirmed / announced_complete / cancelled / archived / available / expired / used / dismissed` |
| time | precision=`exact / approximate / range / date_only / unknown`；targetAtUTC、windowStartUTC、windowEndUTC、expiresAtUTC 均可空，ISO 8601 UTC；存在明确原文证据才赋值 |
| timeMeaning | `automatic_reset / grant_availability / grant_expiry / unknown`；重置券不能被标记成自动重置 |
| timeEvidence | rawText、sourceZoneRaw、sourceZoneIANA、sourceOffset、referencePublishedAtUTC、resolution=`rule / user_confirmed / unresolved` |
| evidence[] | sourceId、sourceItemId、authorId、原文 URL、publishedAtUTC、fetchedAtUTC、contentHash、简短摘录；转引链须回溯原作者 |
| relevance / provenance | relevant/irrelevant/unknown；primary/rereported/manual；来源权威性与时间精度独立 |
| firstSeenAt / updatedAt | UTC；历史排序和修订追踪 |

`SourceStatus`：sourceId、enabled、lastAttemptAt、lastTransportSuccessAt、lastCoverageSuccessAt、latestCoveredPublicationAt、nextCheckAt、scheduledIntervalSeconds、result、errorCategory、consecutiveFailures、etag、lastModified。result 包含 not_connected/checking/success/partial/failed/stale。304 可代表本轮传输成功，但不能刷新聚合源底层抓取时间。

`UserPreferences`：schemaVersion、locale=`zh-Hans/en`、displayTimeZone=`Asia/Shanghai`或`system`、theme、productFilter、planFilter、audioEnabled、volume、reminderOffsets、quietHours、autoExpandNewEvents、launchAtLogin、windowMode/frames/displayId、detailsExpanded、reduceTransparency。普通设置本地保存；免费首版没有 X 凭据。

通知以 eventId、revision、阈值、语言和声音设置组成稳定标识。每次协调都对照系统 pending requests，删除旧 revision、已取消和已结束事件的提醒，再创建尚未到期的节点。事件语义无变化不增加 revision；翻译和阅读量不参与内容意义比较。

数据目录：`~/Library/Application Support/ResetRadar/`。events.json、source-status.json、preferences.json 原子写入，并保留最近一份可解码备份。读取时验证版本；损坏时恢复备份并在界面报告，不清空冒充无公告。系统待发提醒本身作为可协调清单，不另存通知账本。X 内容留存及公开再分发方式在发布前按当时平台条款核查，尽量保存 ID、链接和派生事件，不打包原帖数据库。

## 模块与文件布局

```text
ResetRadar.xcodeproj
ResetRadar/
  App/ResetRadarApp.swift, AppDelegate.swift
  Domain/ResetEvent.swift, SourceStatus.swift, Preferences.swift
  Sources/AnnouncementSource.swift, RSSSource.swift, AtomSource.swift
  Parsing/AnnouncementClassifier.swift, TimeResolver.swift
  Services/PollingCoordinator.swift, EventReconciler.swift
  Services/ReminderScheduler.swift, ClockService.swift, SoundService.swift
  Persistence/LocalStore.swift
  UI/FloatingPanelController.swift, MenuBarController.swift
  UI/CountdownView.swift, MiniView.swift, SettingsView.swift
  UI/SourceDetailView.swift, HistoryView.swift, ManualEventView.swift
  Resources/Localizable.xcstrings, Assets.xcassets
ResetRadarTests/
  TimeResolverTests.swift, PollingTests.swift, ReconciliationTests.swift
  ReminderTests.swift, PersistenceTests.swift
fixtures/                         # 含糊/明确/取消等合成夹具
scripts/build.sh, package.sh, notarize.sh
.github/workflows/ci.yml, release.yml
```

首版只有进程内接口，无需 HTTP API、Web 路由和本地服务端。核心服务接收可替换的 Clock/Source 协议，方便用同一规则回放夹具，避免 UI 自行推导状态。

```swift
protocol AnnouncementSource {
    func fetch(validators: CacheValidators?) async throws -> SourceBatch
}
// SourceBatch: items, coverage, fetchedAt, upstreamFetchedAt?, cacheValidators
// classify(items) -> candidates；resolveTime(candidate) -> resolved / needsReview
// reconcile(candidate, storedEvents) -> inserted / revised / unchanged
// nextPoll(sourceStatus, events, now) -> Date
// plannedReminders(event, preferences, ledger, now) -> [Reminder]
```

## 免费 RSS / Atom 接入

首版预置 ModelYard RSS、Codex Reset Atom、OpenAI News/Status RSS，无账号、密钥或收费请求。新增 Atom XML 命名空间解析与稳定 ID；通过原帖 ID/规范化 URL 去重，站点自己的文章 ID 只用于站内更正。获取每轮全部 feed 条目，按稳定 ID + 内容哈希比较，不只看最新时间，否则会漏掉旧条目修订。

保留 sourceKind=community_feed/official_feed/manual、原帖链接、原文片段、communityPublishedAt、originalPublishedAt（可空）。显示“社区转引”，不能把社区标题中的 Official 直接升级为一手证据。引用原文与摘要冲突以待确认处理；跨源同帖不增加虚假的独立证据数。

RSS 的 pubDate、Atom updated 可能是文章更新时刻，不能作为“tomorrow”的原始发帖锚点。文章最后更新时间也不能当成上游抓取成功时间。SourceStatus 增加 upstreamFetchedAt 可空、upstreamHealth=known/unknown/stale、cacheFreshUntil；传输可达与上游状态未知可以同时存在。条目长时间无新增不自动宣判来源故障。

使用 HTTPS、超时、体积上限；XMLParser 禁用外部实体。缓存 ETag/Last-Modified，遵守 Cache-Control、Age、Expires 与 Retry-After；没有缓存标头时按源默认周期。默认社区源 300 秒；Cache-Control max-age=300 的源不能通过额外轮询/随机参数实现所谓“1 分钟实时”。stale-while-revalidate 可能进一步延后；显示内容来源时间。

站点网页 403 或登录页不能绕过；它公开的 RSS 仍能使用时标记对应覆盖。HTTP 403/429、站点改为收费、XML 结构变化分别显示状态，不自动接入付费 API。

未来可扩展 `PublicJSONSource` 读取免费 `https://codex-reset.com/api/feed`，此接口本次无凭据返回 200，并包含 fetched_at、stale、tweets；公开 JSON 与 Atom 目前覆盖不同，实施前需比较。它不要求用户配置 X API。概率字段、预测窗口、投诉热度不能生成确定重置事件。尚不将该扩展或付费 XSource 纳入首版。

来源链接只允许 http/https，外来文本按纯文本呈现，不执行源内指令。不会在公开诊断中打包全文帖子或个人手动备注。服务条款和数据留存以发布时核查为准。

## 时间解析与时钟

解析优先序：显式完整时间戳及偏移 → 日期+清晰 IANA/地域时区 → 有充分锚点的相对日期 → 手工确认 → unresolved。

- `2026-09-09 14:00 PT` → America/Los_Angeles 当日 PDT → `2026-09-09T21:00:00Z` → 北京 `2026-09-10 05:00`。
- `2026-12-09 14:00 PT` → 当日 PST → `2026-12-09T22:00:00Z` → 北京 `2026-12-10 06:00`。
- 原文 9 月写 PST：字面固定 -08:00 与洛杉矶夏令时冲突。保存两个解释供核实，不默默改成 PDT。
- `tomorrow at 2pm` 没有来源语境时区 → unresolved；浏览器显示的发帖时间可能已本地化，不能视为作者时区。
- `tomorrow morning` → date_only 或 range，只有明示可用区间才填范围；不能自行定义“上午 9 点”。
- 夏令时跳变不存在/重复的当地时刻 → unresolved，除非原文有明确偏移；不能用系统默认选择。
- `already reset / now / rolling out in the next hour` 是完成公告或发布窗口，不能从抓取时刻加一小时假装预定重置。

显示剩余值用 `max(0, ceil(targetUTC - effectiveNow))`；每次重绘重新计算，不逐次减一。2026-09-09 用户追加要求：取消天数，只显示累计小时 `HH:mm:ss`，小时数取总秒数整除 3600，不对 24 取模。小于 100 小时至少两位补零；100 小时显示 `100:00:00`，一周显示 `168:00:00`。主窗和迷你窗预留三位小时，三位是常规布局预留而非截断上限；更大值仍显示真实累计小时并自适应字号，禁止回绕、封顶 99 或恢复天数。中英文共用纯数字格式。通过连续时钟与系统时间差检测运行中调钟；系统时钟明显跳变时提示并重算提醒。首版以系统自动校时为基础，不把普通 HTTP Date 当权威时间源。睡眠恢复立即重读当前时间、刷新事件、取消失效本地通知并合并补提醒。

## 调度、提醒与窗口

PollingCoordinator 用 actor 保证单来源不重入，手动刷新/联网恢复/定时触发合并。先写 attempt，再请求与解析，再原子写事件和 coverage；UI 可观察各步骤。免费 RSS/Atom 以 300 秒为默认，并遵守服务端缓存下限；不使用提前抖动绕过缓存。未来免费 JSON 扩展可按 PRD 使用 5/2/1 分钟策略。

建立事件或修订后统一重排本地通知，以稳定标识替换；关闭事件视图不会删掉计划。用户开启免打扰时记 suppressed，恢复后仅补当前有效提示。离线跨越多个提醒点一次合并；断网导致到点无法确认时仍允许本地“已到预计时间”，不能变成“已重置”。

同一事件多个来源只增加 evidence，不重复 discovery。时间更正创建一个重要修订提示；旧 revision 的未发提醒全部取消，新计划不补发已经过时的阈值。

启动导入与日常增量采用同一事件解析器，但分别处理提醒：首次导入过去事件只落历史与去重基线，不能使用 firstSeenAt 判断它刚刚发布。明确未来的有效预告可立即提醒一次；多事件合并。旧 banked reset 没有有效期或当前生效证据时不主动提示可用。源中缺失某条历史记录不代表撤回，只有明确取消证据才改变事件状态。

正常退出路径先撤销该应用待发的 UNNotificationRequest，再结束进程；隐藏/关闭浮窗不撤销。启动时依据账本和当前时间重新安排尚有效节点。崩溃后无法执行清理，因此不保证退出清理覆盖强制终止；下次启动核对系统 pending requests 并去重。

AppKit 采用 NSPanel 与 SwiftUI hosting，验证 nonactivatingPanel、floating level、hidesOnDeactivate=false、canJoinAllSpaces/fullScreenAuxiliary；这些是实现候选，是否覆盖别的全屏应用必须 M0 真机证明。不能单凭 flag 宣称实现。[Apple Spaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)；[全屏辅助窗口](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary)

当前屏幕按首次弹出时鼠标所在屏幕确定，后续尊重用户拖动屏幕；使用 visibleFrame，避开菜单栏、刘海和 Dock。普通浮窗不获取文本输入焦点，设置/手动录入使用常规 NSWindow。面板关闭与应用退出分别处理。

## 玻璃、折叠与语言契约

主窗折叠是默认模式，详情开关独立于 windowMode。`中 / EN` 是浮窗内常驻双段按钮，两个选项始终可见并有选中状态；迷你窗也具备同一控件。语言切换不创建新事件、不改变 UTC、提醒账本或展开状态。

SwiftUI 根据 macOS 26 availability 使用 glassEffect/GlassEffectContainer；AppKit 方案用 NSGlassEffectView，二者选一种与 NSPanel 承载方式匹配的实现，不层叠两套玻璃。14/15 回退 NSVisualEffectView；accessibilityDisplayShouldReduceTransparency 时实色，reduce motion 时无展开动画或光带。真机检查深色/浅色桌面下对比度与 CPU。

折叠主窗 412 × 294 pt 左右，展开按实际详情自适应（原型约 500 pt）。没有小时/分钟/秒钟三个标签。高光与主数字根据 exact/urgent/grant/empty/vague/due 使用琥珀/珊瑚红/绿/灰/紫/金色，并辅以图标和字号字重。查询异常用独立健康标记，不能将事件清空。新事件只播放一次强调动画。

## 本次原型边界

`design/prototype.html` v2 是单文件离线交互样稿，所有状态和查询均为演示。支持玻璃模拟、折叠/展开、浮窗内双语切换、八种状态、拖动/迷你/隐藏、时区、深浅色、降低透明度和声音试听。没有对真实源发请求。浏览器 CSS 不等于原生 Liquid Glass，不验证跨应用置顶、系统通知和后台采集；仍需 M0/M3 真机工作。
