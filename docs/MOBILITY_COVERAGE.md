# Mobility 技能覆盖与边界（Alpha.12 范围修订）

本表描述源码已接入的 **当前职业、当前专精、实际已学技能**，不是全技能在真实客户端均已通过验收的声明。法师 Blink / Shimmer 延续用户已经实测通过的路径；本轮新增技能的真实战斗验收均待进行。离线测试结果由交付测试报告单独记录。

## 当前范围

保留 Alpha.11 已接入的普通 Mobility 监控。本阶段开发目标是法师真实 Proc；Mobility 唯一新增候选为 **Free move：用户已确认对应 Time Spiral，实际接入状态见本轮交付文档**。特殊返回、特殊天赋、传送门及其他免费重施均不再是开发目标或用户必做验收项。纯未实现分支不再出现在可用 Preview 列表；已支持技能仍保留必要的安全拒绝与恢复检查，不以删除保护冒充支持。

本表下文保留已有实现证据和安全边界，不构成扩大范围的待办清单。Free move 对应用户已确认的 Time Spiral 免费使用效果，不等同于 Hover 的移动施法持续时间。

## 数据来源与版本

目标数据为 **Retail 12.1.0.69933**。技能名字、技能 ID、普通冷却、GCD、充能分类与恢复时间来自以下可追溯的客户端数据；恢复时间只用于核查，绝不作为运行中倒计时。

- [SimulationCraft 提取数据，固定提交 18429d2f8fd75ebe7be92fec37394055a0254b77](https://github.com/SimulationCraft/simc/tree/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump)。各职业文件头均标记 `12.1.0.69933 Live`。定义中的 `class.txt#L…` 指该提交的文件、按实际 LF 计数的行号。
- [SpellName，固定 build 69933](https://wago.tools/db2/SpellName/csv?build=12.1.0.69933) 与 [Spell 描述](https://wago.tools/db2/Spell/csv?build=12.1.0.69933)：补全被 SimC 技能筛选遗漏的 Shadowstep、Demonic Circle: Teleport、Transcendence: Transfer、Wild Charge 水栖形态；也确认旧称 Displacement 的技能 389713 在此 build 叫 **Reflection**。
- [SpellCooldowns](https://wago.tools/db2/SpellCooldowns/csv?build=12.1.0.69933)、[SpellCategories](https://wago.tools/db2/SpellCategories/csv?build=12.1.0.69933)、[SpellCategory](https://wago.tools/db2/SpellCategory/csv?build=12.1.0.69933)：交叉核查普通冷却、分类冷却、GCD、充能分类。`Wago:表名:数字` 是表的行 ID；`spellID=…` 明确表示按 SpellID 过滤。

数据没有从其他 AddOn 复制完整职业数据库。所有候选项在职业工厂被调用时才生成；按原生已学状态与替换关系筛选后才成为活动提醒。法师原有适配器保留，额外返回技能通过独立工厂附加。

## 13 职业、40 专精的候选范围

下面“通用”只表示该职业工厂会提供候选，**没有学会的技能不会监控**。不会把一个专精的技能当成其他专精已拥有；无专精角色只获得通用候选。

| 职业 | 专精 ID | 通用候选 | 专精额外候选 |
|---|---|---|---|
| Warrior | Arms 71 / Fury 72 / Protection 73 | Charge、Heroic Leap、Intervene | Protection：Shield Charge |
| Paladin | Holy 65 / Protection 66 / Retribution 70 | Divine Steed | — |
| Hunter | Beast Mastery 253 / Marksmanship 254 / Survival 255 | Disengage、Aspect of the Cheetah | Survival：Harpoon |
| Rogue | Assassination 259 / Outlaw 260 / Subtlety 261 | Sprint、Shadowstep | Outlaw：Grappling Hook |
| Priest | Discipline 256 / Holy 257 / Shadow 258 | Angelic Feather | — |
| Death Knight | Blood 250 / Frost 251 / Unholy 252 | Death's Advance、Wraith Walk | Frost / Unholy：Death Charge 替换候选 |
| Shaman | Elemental 262 / Enhancement 263 / Restoration 264 | Spirit Walk、Gust of Wind、Wind Rush Totem | Enhancement：Feral Lunge |
| Mage | Arcane 62 / Fire 63 / Frost 64 | 原有 Blink / Shimmer；额外返回不在范围内 | — |
| Warlock | Affliction 265 / Demonology 266 / Destruction 267 | Demonic Circle: Teleport | — |
| Monk | Brewmaster 268 / Windwalker 269 / Mistweaver 270 | Roll / Chi Torpedo、Transcendence: Transfer、Tiger's Lust | Windwalker：Flying Serpent Kick |
| Druid | Balance 102 / Feral 103 / Guardian 104 / Restoration 105 | Dash / Tiger Dash、Wild Charge 形态家族、Stampeding Roar 形态家族 | — |
| Demon Hunter | Havoc 577 / Vengeance 581 / Devourer 1480 | 初始 Fel Rush、Vengeful Retreat | Havoc：Fel Rush、Felblade、The Hunt、Metamorphosis；Vengeance：Infernal Strike、Felblade；Devourer：Shift、Voidblade、The Hunt |
| Evoker | Devastation 1467 / Preservation 1468 / Augmentation 1473 | Hover、Deep Breath、Verdant Embrace、Rescue | Devastation：可操纵 Deep Breath；Preservation：Dream Flight；Augmentation：Breath of Eons 家族 |

这是本轮明确核查并接入的候选范围。不会把种族、物品、传送门、飞行、所有伤害技能中的短移动、被动加速或队友移动效果统称为已实现。后续新版本增加的未知替换不会自动套用一个旧技能的计时规则。

## 技能、机制与实现状态

“接入”表示有真实 API 路径：普通冷却走原生冷却时长；充能走当前实际充能数和下一次恢复的原生时长。秘密充能走单技能核查过的原生可见性分类；客户端 C++ 时长选择行为仍须实际验收。未知、受限或不匹配的分支会明确降级。

| 职业 | 提醒家族 / 实际 ID | 机制、实现与限制 | 离线验证 | 真实客户端验收 |
|---|---|---|---|---|
| Warrior | Charge 100；Heroic Leap 6544；Intervene 3411 | 已接入充能路径；分别核查普通/分类间隔。额外充能与恢复变化由 API 决定。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Warrior | Shield Charge 385952 | Protection 实际已学时接入普通冷却；距离、目标或怒气不能成为耗尽判断。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Paladin | Divine Steed 190784 | 已接入充能；不把各个种族坐骑外观效果当成额外技能。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Hunter | Disengage 781；Harpoon 190925 | 已接入充能；Harpoon 仅 Survival 候选。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Hunter | Aspect of the Cheetah 186257 | 已接入普通冷却。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Rogue | Sprint 2983 | 已接入普通冷却。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Rogue | Shadowstep 36554；Grappling Hook 195457 | 已接入充能；**学会 Death's Arrival 454433 时 Unsupported**，其临时免费再次使用不在范围内，保留安全拒绝。Shadowstep 的基础分类最大充能为 0，实际充能由学习/天赋赋予；不硬编码最大充能。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Priest | Angelic Feather 121536 | 已接入充能耗尽；监控“还能否放置羽毛”，不推测地上是否仍有羽毛或角色是否正在加速。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Death Knight | Death's Advance 48265 / Death Charge 444347 | 替换家族只选择当前有效技能，已接入充能。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Death Knight | Wraith Walk 212552 | 已接入普通冷却；不把引导中、沉默或控制当成额外耗尽条件。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Shaman | Spirit Walk 58875；Gust of Wind 192063；Wind Rush Totem 192077；Feral Lunge 196884 | 已接入各自普通冷却；前两者按已学天赋筛选，Feral Lunge 仅 Enhancement；Wind Rush 监控放置图腾技能的冷却，不推测角色是否处于加速范围。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Mage | Blink 1953 / Shimmer 212653 | 保留原有用户实测通过的独立识别、战斗显隐与下一次充能时长路径。 | 源码离线回归通过；解压包结果见测试报告 | 历史用户实测通过；Alpha.11 安装回归待验收 |
| Mage | Alter Time 342245 / 返回 342247 | **Unsupported**：初次施法在冷却时仍可能返回。不能用初次冷却冒充返回能力已经耗尽。 | 源码安全拒绝夹具通过；解压包结果见测试报告 | 不在范围内；无用户验收要求 |
| Mage | Reflection 389713 | **Unsupported**：依赖上次 Blink / Shimmer 的条件返回窗口；没有已核验的原生“下次返回可用”计时路径。不会用固定窗口模拟。 | 源码安全拒绝夹具通过；解压包结果见测试报告 | 不在范围内；无用户验收要求 |
| Warlock | Demonic Circle: Teleport 48020 | 已接入传送技能自身冷却，不监控放置法阵的 48018。没有法阵或距离过远并不显示耗尽。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Monk | Roll 109132 / Chi Torpedo 115008 | 当前有效替换只出现一个提醒，已接入充能；两者的短间隔规则独立核查。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Monk | Transcendence: Transfer 119996 | 已接入交换位置技能自身冷却，不使用放置分身 101643 的冷却；不存在分身或距离不合适不等于耗尽。Linked Spirits 434774 只修改放置方式；119996 仍按实际原生 API 读取。候选 ID 1294390 在此 build 的 SpellName / Spell / 冷却 / 分类表均不存在，未添加该未知映射。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Monk | Tiger's Lust 116841 | 全专精实际已学时接入普通冷却，监控施放能力而非速度 Buff。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Monk | Flying Serpent Kick 101545 / 落地阶段 115057 | 初次技能接入普通冷却；**落地再按阶段 Unsupported**，不能拿落地按钮时间当成下一次起飞的恢复时间。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Druid | Dash 1850 / Tiger Dash 252216 | 替换家族，已接入普通冷却。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Druid | Wild Charge 102401 / Bear 16979 / Cat 49376 / Moonkin 102383 / Travel 102417 / Aquatic 102416 | 一个形态家族；当前原生替换决定计时对象，已接入共享普通冷却。水栖形态为游泳加速效果，没有伪造冲锋/跳跃。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Druid | Stampeding Roar 106898 / Bear 77761 / Cat 77764 | 一个形态家族，已接入普通冷却；不重复显示同一能力。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Demon Hunter | 初始 Fel Rush 344865 / Havoc 195072 / Vengeance Infernal Strike 189110 / Devourer Shift 1234796 | 一个专精替换家族；当前专精只实例化对应候选。四者分别核查充能间隔；不统一假设两次充能。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Demon Hunter | Vengeful Retreat 344866 / 198793 | 同家族 starter / 当前技能原生替换；普通与充能路径分别处理，不同时重复监控。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Demon Hunter | Felblade 232893；Voidblade 1245412 | Havoc / Vengeance Felblade 普通冷却；Devourer Voidblade 充能；只在对应专精生成候选。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Demon Hunter | The Hunt 370965（Havoc）/ 1246167（Devourer）；Metamorphosis 191427（Havoc） | 已接入普通冷却，前者为真实冲锋、后者为真实跃迁；其他专精不套用 Havoc 变身的移动机制。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Demon Hunter | Fel Rush 返回阶段 427785 | **Unsupported**：返回按钮不等于下一次正常 Fel Rush 的充能恢复，不取短返回间隔冒充真实恢复。 | 源码安全拒绝夹具通过；解压包结果见测试报告 | 不在范围内；无用户验收要求 |
| Evoker | Hover 358267 | 已接入位移充能；Hover 移动施法 Buff 不在范围内。Free move 是独立 Time Spiral 接收增益，见 alpha.12 Proc/Free move 文档。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Evoker | Deep Breath 357210 / 可操纵 433874 / 原生替换 1236943；Breath of Eons 403631 / 可操纵 442204 | 同家族按当前专精和实际替换选择，分别使用充能或普通冷却。**学会 Strafing Run 1266151 时整个飞行家族 Unsupported**，该免费重施分支不在范围内，保留安全拒绝。1236943 的普通冷却与移动效果已核查，只有基础技能实际原生替换到它才激活；其他未知替换仍报告诊断。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Evoker | Verdant Embrace 360995 | 已接入充能；DB2 的 RecoveryTime=0、CategoryRecoveryTime=500，SimC 有效普通冷却=500。运行时 `GetSpellBaseCooldown` 必须符合已核查元数据，否则受限路径降级；不会强行接受不同返回值。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Evoker | Rescue 370665；Dream Flight 359816 | 已接入普通冷却，Dream Flight 仅 Preservation；不把无目标等条件当成耗尽。 | 源码离线 API 夹具通过；解压包结果见测试报告 | 新增路径待真实战斗验收 |
| Evoker | Recall 371838 | 只有当前原生基础技能实际替换为 Recall 时才纳入相应家族，单独已学 Recall 不猜测来源。飞行家族的返回阶段为 **Unsupported**；避免把可返回状态的按钮计时当成下一次原始飞行计时。 | 源码安全拒绝夹具通过；解压包结果见测试报告 | 不在范围内；无用户验收要求 |

## 不在范围内的机制与保留的安全边界

- Alter Time / Reflection、Fel Rush 返回、Flying Serpent Kick 落地、Recall、Death's Arrival、Strafing Run、Demonic Gateway、其他免费重施与被动/形态加速不在本阶段范围内。已存在的拒绝分支仅防止普通监控误报，不列为后续阻塞项，也不提供伪装可用的样例入口。
- Free move 的唯一新增请求已由用户确认对应 Time Spiral；本轮接入状态另列，不借此扩展其他免费重施机制。
- 未知替换、受限已学/替换状态、缺少原生计时接口、未通过元数据守卫的秘密多充能仍报告 Unknown / Restricted / Unsupported，不当成 Ready / Depleted，也不输出模拟数字。

## 原生路径与不变量

计时对象与显隐对象分工独立。充能耗尽数字绑定“已进行中的下一次充能恢复”，不从最后一次施法重新起算；原生透明度仅用于可见性。至少一次可用时不可见，恢复一次就不可见，不等待全部回满。普通冷却使用排除 GCD 的原生对象。所有分类结果即使为 secret，也只传递到允许的显示接口。

每条新充能规则都有独立普通冷却/GCD/分类间隔依据，并在运行时核对公开基础元数据。阈值不是倒计时。正常 GCD、目标、距离、资源、控制等原因不能用 `IsSpellUsable=false` 转换成耗尽。23 条新原生分类规则详见 API 核查文档和代码的 `chargeVisibility`；不能把“离线分类测试通过”写成 C++ 已在真实客户端逐技能验证。

配置仍按职业隔离；法师换专精不新建 Mobility 配置。候选定义不是 SavedVariables。当前职业多个并存技能复用该职业样式，提醒绑定只处理当前活动技能，不扫描所有职业。关闭 Options / Preview 不停止真实监控。按需加载与配置加载的实际边界以加载审计文档为准。

## 已接入普通 Mobility 的可选客户端回归步骤

1. 记录完整客户端 build、职业、专精、已学天赋和实际活动技能列表。分别登录、打开/关闭 Options、启动/停止 Preview，确认 live 一直运行。
2. 对每个普通冷却技能：正常施放 → 真实倒计时；结束立即不可见。只触发 GCD、无效目标、超出距离或资源不足时不得误报。
3. 对每个充能技能：最大值以客户端为准；从多次可用耗到剩一次应隐藏，最后一次耗尽才显示，恢复一次立即隐藏。两次使用间隔数秒时，数字应继续已有恢复周期。
4. 进战斗、脱战、再次进战斗、战斗中重置/额外充能、减冷却、急速变化均验证，不允许只验证普通可读数据。诊断 Native tracking 不等于 Lua 已知最终显隐状态。
5. 切换天赋替换、专精和德鲁伊形态，确认活动 ID 更新、无旧提醒残留、无重复绑定；返回原职业/专精设置不丢失。
6. 本轮法师 Proc 验收与 Free move 确认另见对应交付文档；排除的特殊机制不要求用户补测或完成。
