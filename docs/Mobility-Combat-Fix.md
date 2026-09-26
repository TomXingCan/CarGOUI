# CarGOUI 0.1.0-alpha.6 — 战斗显隐与固定职业色

在 alpha.5 `1076f4158af0663cee58bce76fec99b58a75f816` 上增量修改，沿用 PR #1 / `feat/options-window`。未回退 alpha.4 或已完成的 Options 功能。

## 修改内容

- `Modules/Mobility/SpellState.lua`：保留秘密值检查，移除“秘密次数必定结束监控”的单一路径。公开次数仍精确判断；单次容量正在恢复时使用公开状态；多次容量由普通冷却的原生总 BaseTime 曲线控制透明度，计时取独立的下一次充能恢复对象。
- `Modules/Mobility/Runtime.lua`、`UI/Display.lua`：持续提醒更新时保留绑定，不先隐藏和清空；原生显隐结果直接送进父框体 `SetAlpha`，不读取/比较结果。数字继续由原生 DurationTextBinding 格式化，绕开普通字符串和尺寸测量。
- `UI/ReminderStyle.lua`：共用、不可自定义的暴雪职业色，名称和数字一致。按玩家 class token 缓存复制的 RGB；无有效颜色先用白色并允许恢复。初始化/进世界、字体刷新和框体复用都应用颜色；不写入账号配置、不修改全局颜色表、不改父框体透明度。
- 不改 `UI/Preview.lua` 的独立状态和清理职责。复查并测试确认，停止预览与关闭 Options 后继续实时查询；进入战斗只结束模拟和装饰动画，不结束 live。

不新增颜色设置、常驻扫描、每帧查询或第三方依赖。原位置、字体、字号、缩放、`/cui`、可移动 Options、Enter 保存、滑块实时更新和现有标题均保留。SavedVariables schema 仍为 3；本次没有颜色字段或配置迁移。

## 当前可交付状态

代码与离线回归测试已交付，最终 ZIP 解压目录使用同一套测试复测；实际结果、文件哈希与版本以随包的 `CarGOUI-alpha.6-Test-Results.txt` / `CarGOUI-alpha.6-SHA256.txt` 为准。旧版 ZIP 和测试记录保留，不混用版本证据。

源码/API 数据核查目标为 **12.1.0 build 69933**；本轮**没有真实客户端测试环境**。用户确认的是 alpha.5 战斗外可用、战斗内不显示。不能据此或离线 mock 宣称 alpha.6 的完整战斗支持已经验收。

多充能受限路径需要公开 `GetSpellBaseCooldown` 元数据符合已查阅的普通间隔/GCD边界，并需要普通冷却对象能区分剩余充能与耗尽。缺接口、元数据受限或边界不符时，明确 `Restricted` 并隐藏；如果客户端的原生总时长选择在临近恢复/特殊缩减时不满足区分条件，仍可能漏报或误报。原生正常跟踪时诊断为 **Native tracking**，不伪称 Lua 已知最终显隐。

具体接口、证据和限制见 [API 核查](Mobility-Combat-API-Audit.md)。游戏内请按 [验收步骤](Mobility-Combat-Acceptance.md) 检查，尤其是战斗中 2→1→0→1、最后一次在前次快恢复时消耗，以及冷却重置/缩减。这些待验收项仍属于现有 Mobility 修复，不转入真实 Proc、全职业或美化工作。
