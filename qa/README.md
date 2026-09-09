# 独立验收复现

这批材料最初审查提交 `d0d7e8919038a5043559f86922b8276bd004c9ec`，不属于发布应用或原有测试目标。在该基线上 `AcceptanceAuditTests.swift` 有 21 个失败测试（22 个失败断言）；验收修复后，同一批 26 个场景应全部通过。历史失败输出保留在 `results/acceptance-tests.txt`，用于说明问题确实被复现过。

## 单元/服务场景

从项目根目录运行，下列操作仅写临时目录：

```sh
audit_dir=$(mktemp -d /tmp/reset-radar-acceptance.XXXXXX)
git archive HEAD | tar -x -C "$audit_dir"
cp qa/AcceptanceAuditTests.swift "$audit_dir/ResetRadarTests/AcceptanceAuditTests.swift"
swift test --package-path "$audit_dir" --filter AcceptanceAuditTests
```

测试用独立 `LocalStore` 和模拟 URLProtocol，不访问真实订阅、不写用户应用数据、不申请通知权限。原有 23 项用例用项目根目录 `swift test -Xswiftc -warnings-as-errors` 运行。

## 原生 UI 夹具

`AuditAppMain.swift` 仅用于临时副本中替换 `ResetRadar/App/ResetRadarMain.swift`。用原有 MonitorModel / CountdownView / MiniView / FloatingPanelController，给每轮场景创建临时存储；来源 nextCheckAt 设为一天后，关闭声音，不注册系统通知。

构建：在另一份临时副本中复制该入口，执行 `swift build --package-path <临时副本>`。将构建产物放入独立 `.app`，使用不同 bundle ID `dev.resetradar.acceptance-audit`，不要替换 `/Applications/Reset Radar.app`。菜单提供 Automatic countdown / Grant expiry countdown / Undated grant / English 100 hours / Empty，20 秒场景用于观察自然归零。切换菜单仅更新夹具。

Grant expiry 场景的 `targetAt` 模拟的是 A01 已复现的错误解析结果，不代表认可这一数据设计。夹具启动入口不同于产品入口，因此不能用它证明真实通知、正式应用启动恢复或开机启动行为通过。测试期间不要点“立即查询”或更改系统权限。

## 保存的证据

- `results/baseline-tests.txt`：原有 23 项通过。
- `results/acceptance-tests.txt`：26 项独立测试完整输出。
- `results/native-ui-observations.md`：原生界面观察记录；截图已在本次验收会话中返回。
- `../docs/ACCEPTANCE_AUDIT.md`：结论、失败项、代码位置及未验证边界。

本次未发布这些验收文件。没有将合成事件注入已安装应用。
