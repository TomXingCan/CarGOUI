# Phase 2A — 游戏内验收

目标版本 `0.1.0-alpha.5`。本清单是待执行验收，**不代表已在真实客户端通过**。用户此前认可的是界面大致效果；本轮真实技能、战斗、secret value、taint、原生计时还没有客户端测试证据。离线结果与最终解压包复测、ZIP SHA256 见交付测试报告。

## 准备与记录

1. 退出游戏，将交付 ZIP 内 `CarGOUI/` 替换到 `_retail_/Interface/AddOns/CarGOUI/`，确认 `CarGOUI.toc` 直接在该目录。保留 WTF SavedVariables，不重置已调好的位置。
2. 建议先只启用 CarGOUI，用 `/console scriptErrors 1` 开启 Lua 错误弹窗。登录法师，输入 `/cui` → Mobility，确认 `Enable Mobility` 和 General → `Show reminders (live and test)` 均开启。
3. 点击 `Copy diagnostics` → `Select all` → Ctrl+C，保存版本、实际客户端 build/Interface、职业/专精、识别技能、状态、Path 和 Reason。切换场景或天赋后点击 `Refresh snapshot` 再复制。
4. 先点击 Stop test，再关闭 Options。以下真实提醒应无 TEST 标记；不要把固定 `8.0` 样例当作成功。

## 真实技能矩阵

以下分别在**城镇、木桩战斗、至少一次实际副本战斗**执行，并记录成功或具体限制。两种天赋 Blink / Shimmer 都要测试；三个法师专精分别验证识别与保存位置，未选专精低等级角色验证已学/未学状态。

| 操作 | 预期 |
| --- | --- |
| 当前可用次数满 | 无真实提示；识别正确，不要求固定两次。 |
| 至少两次时只消耗一次 | 还有一次，即使另一层在充能也完全不显示。 |
| 消耗至零 | 出现正确的 No Blink / No Shimmer 和真实剩余时间，无大框、图标或 TEST 引导。 |
| 先消耗一次，等数秒后再消耗最后一次 | 显示第一轮已经走过一部分的充值剩余时间，不能从完整冷却重新计时。 |
| 从零恢复第一次可用 | 立即隐藏，不等其余充能全部回满。 |
| 实际上限为一次 | 依据客户端真实一次上限工作，不因不是两次而失效。 |
| 非充能 Blink 自身冷却 | 自身冷却时显示，恢复后清除；使用普通触发 GCD 的其他技能不能造成位移耗尽提示。 |
| 法力不足、沉默、距离/不可施法、施法失败 | 在仍有位移次数或没有自身冷却时，不因这些原因显示耗尽。 |
| 提前恢复/冷却重置（若当前角色有合法可用方式） | 新 API 状态优先，旧倒计时立即消失，不继续数到旧结束点。无法制造此场景时记“未测”，不伪造通过。 |
| 学习或取消 Shimmer、切换三个专精 | 只监控当前有效技能，不出现 Blink/Shimmer 双提醒；同专精切换保留原位置。 |
| 未选专精的低等级法师 | 已学 Blink 能监控；未学两技能时 Not learned 且无提示，不通过资料存在认定已学。 |
| 非法师 | Unsupported，无真实输出或其他职业技能扫描。 |

## 重载、预览与设置回归

1. 耗尽后仍在冷却时 `/reload`，确认直接恢复当前真实剩余时间，不能需要再次施法才启动。进出副本、死亡、释放灵魂与复活后再次确认状态。
2. 关闭 `/cui` 和 Test Mode，重复一次耗尽/恢复：真实提醒继续工作。打开 Options 不应停止真实状态同步。
3. 打开 Mobility → `Test current spell`，样例显示 TEST 与固定 `8.0`，同区域不叠加真/假数字。测试期间发生真实状态改变后 Stop test，恢复的是新状态，不是预览开始前的快照。关闭 Options 同样清掉样例并恢复真实状态。
4. 打开 Proc 单条模拟时，另一区域的真实位移提醒仍能出现。启动 Test current spec 时避免该位移区域叠加；停止后立即重新同步。
5. 在 Test Mode 中进入战斗：样例自动结束，战斗中启动模拟按钮禁用/给出说明；真实模块继续工作。现有标题进入静态，脱战按原开关恢复，不因每次技能状态刷新重启动画。
6. 修改 Mobility 区域 X/Y，在任意输入框按 Enter 同时提交；另一轴无效时两轴都不变。Scale、Font size 滑块实时生效，精确输入按 Enter 生效。live 与 TEST 应使用一致字体、大小、描边、阴影、全局及区域位置。
7. 验证旧的三个 `mage_*_shimmer` 位置、全部 Proc 位置、Options 窗口位置均保留；Blink/Shimmer 共用各专精原位置。未选专精用新增 `mage_unspecialized_mobility` 默认位置，不覆盖三专精。
8. 耗尽显示期间关闭 Enable Mobility，输出立即清理；重新开启立即查询当前状态。重复耗尽/恢复及窗口开关 20 次，观察无 Lua 错误、对象残留或越来越多的回调/刷新活动。
9. `/cui`、`/cargoui` 都应开关窗口，`help` 仍显示帮助；zhCN 客户端仍为英文。标题栏拖动保存、Esc/Close、菜单和输入焦点保留原行为。不要拖动游戏空间提醒，本版没有 Unlock Mode。

## 限制如何判定

- **Restricted / blocked: charge depletion**：实际 `currentCharges` 是 secret，无法合规确认零次；提示被隐藏。这是该客户端/场景未完整支持的精确阻塞，不能把没有提示当作 Ready，也不能以 Preview 成功代替战斗成功。
- **Tracking / native cooldown duration (ignoreGCD)**：非充能内部时间受限但可交给原生 binding；实际画面仍须验证能排除 GCD、结束时清空。这不等同于“只支持战斗外”。
- **Unknown**：API 未返回有效同步状态，例如缺少冷却记录、零次数与 zero duration 不一致，或学习结果与 Blink 的替换结果不一致。尤其核查学习 Shimmer 后 Blink 解析确为 212653；若持续报告 `Learning and Blink replacement disagree`，记录实际天赋与诊断，该情形未完成支持，不能当作零次/Ready。
- **Unsupported**：缺失所需 API、非支持职业或不支持的替换。保留诊断，不尝试改写或绕过秘密字段。

每项记录环境（城镇/木桩/副本）、技能、专精、公开可见的游戏行为、诊断快照、Lua 错误文本。无需记录账号信息。最终可称为完整成功的条件是：**Options 与 Test Mode 都关闭，在真实战斗耗尽后显示正确剩余时间，恢复一次立即隐藏**；任一关键路径受限则明确记录可工作范围与阻塞条件。
