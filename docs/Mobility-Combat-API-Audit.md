# Phase 2A combat fix — API 核查

> **后续反馈：用户已实测确认 alpha.6 Blink / Shimmer 正常。** 下文保留当时的开发/验收记录与接口边界；alpha.7 仅增加独立样式和自动主题，见 [当前说明与验收](ENTRY_STYLES.md)。用户反馈未提供完整 build/场景矩阵，不扩写为所有边界均已通过。

本说明对应 `0.1.0-alpha.6` 的 Blink / Shimmer 增量修复。用户已反馈 alpha.5 战斗外可显示、进入战斗后不显示；这不是新版的实测结果。**本轮没有真实 WoW 客户端；战斗显隐、原生计时与 taint 行为仍待用户验收，不能宣称完整战斗支持已经验证。**

## 核查范围与证据层次

只处理当前实际学习、生效的 Blink `1953` / Shimmer `212653`。目标 API 声明固定到 [Blizzard UI 镜像 `09b9db7`](https://github.com/Gethe/wow-ui-source/tree/09b9db7948abc9b9648dedaab51eb0cf3ee67b31)。补充查阅 SimulationCraft 提取的 [12.1.0.69933 / hotfix 2026-09-24 客户端数据](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/build_info.txt)。用户实际安装的 version/build 尚未知，应以 Options → Mobility → Copy diagnostics 的 `GetBuildInfo()` 为准。

| 验证层次 | 本轮能够确认的内容 | 不能由此推导的内容 |
| --- | --- | --- |
| API 声明核查 | DurationObject、曲线求值、SetAlpha、原生文字 binding 的签名和秘密值参数限制 | 当前客户端对两个技能选取哪一种 cooldown DurationObject |
| 指定 build 的提取数据 | 两技能的普通间隔、GCD、基础充能与已查阅的天赋修改 | 所有环境、后续热修、战斗限制与 C++ 对象选择行为 |
| 离线 mock 合约测试 | 脚本在约定 API 输入下的分支、秘密值使用边界、事件和 UI 生命周期；结果见交付测试输出 | 真正的 secret/taint 执行限制、实际原生像素或游戏内行为 |
| 真实客户端验收 | 由用户按 [验收步骤](Mobility-Combat-Acceptance.md) 执行并记录 build | 本轮尚未执行，不能写成通过 |

未导入 EUI 依赖、全职业数据库、SimulationCraft 运行库或第三方美术。[EUI 指定提交中的 MovementAlert](https://github.com/EllesmereGaming/EllesmereUI/blob/394319df23b67d4b09850a78a8d6a542beb80140/EllesmereUIQoL/EllesmereUIQoL_MovementAlert.lua) 仅用于参考“普通冷却原生求值控制透明度”的接口思路；实现没有整段复制该代码，也没有沿用其固定 1.6 秒边界。

## 根因与采用的路径

alpha.5 的 `ReadMobilityState()` 在 `currentCharges` 为 secret 时直接返回 Restricted，因而从未给真实渲染器提供计时对象。这是已定位的代码路径。新版不通过删除秘密值检查来修复，而是将“是否可见”和“数字显示什么时间”分开。

| 实际 API 条件 | 显隐依据 | 数字来源 / 诊断 |
| --- | --- | --- |
| `currentCharges` 普通可读且有效 | `>= 1` 隐藏；`== 0` 且有效 recharge 时显示 | `GetSpellChargeDuration()`；可以报告 Ready / Depleted |
| 次数 secret，公开 `maxCharges == 1` 且 `isActive == true` | 在容量确为一的前提下，公开恢复活动表示唯一一次正在恢复；不将此推理用于多充能 | 同一个真实 recharge 对象；可以报告 Depleted，但没有读取秘密次数 |
| 次数 secret，公开 `maxCharges > 1` 且 `isActive == true`，原生显隐能力与元数据完整 | 普通 cooldown 对象的总 BaseTime 经原生 step curve 求值，结果直接交给 `SetAlpha` | 数字仍使用 recharge 对象；报告 **Native tracking**，不报告 Lua 已知 Ready / Depleted |
| 次数 secret，但公开 `isActive == false` | 隐藏，并报告 Unknown；无恢复活动也可能来自零时长/数据不可用，不能直接宣称 Ready | 不绑定不存在的活动计时 |
| 没有 charge record，但有有效普通 cooldown record | 独立的非充能路径，普通 duration 排除 GCD | `GetSpellCooldownDuration(spellID, true)`；不能把 nil charge record 本身解释成就绪 |
| 缺少必要接口、有效对象或可信公开元数据 | 明确报告 Unsupported / Unknown / Restricted，并安全隐藏 | 不用旧快照、固定秒数或样例补足 |

`maxCharges` 与 `isActive` 在目标 [SpellChargeInfo 声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua) 中为 NeverSecret；实现仍先做秘密性和类型检查。对于多充能，`isActive` 仅代表正在恢复，绝不等同于耗尽。沉默、控制、距离、法力和 `IsSpellUsable=false` 均不参与耗尽判断。

## 两种时间对象的职责

`C_Spell.GetSpellChargeDuration(spellID)` 返回正在进行中的下一次充能恢复对象。因此第一下已启动恢复、数秒后耗尽最后一次时，数字沿用已有恢复进度，不从最后一次施法重新开始。目标 [Spell API 声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua) 中该 API **没有 `ignoreGCD` 参数**。

多充能且次数受限时，可见性使用 `C_Spell.GetSpellCooldownDuration(spellID, false)`，保留普通冷却对象的原生选择行为；不把 `ignoreGCD=true` 无差别套到这里。它与 charge duration 是两次有不同用途的查询，不能互换。

```lua
-- Public curve and enum; the engine may return secret alpha.
frame:SetAlpha(cooldownDuration:EvaluateTotalDuration(curve,
    Enum.DurationTimeModifier.BaseTime))

-- A separate native binding formats the existing next-recharge duration.
binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
binding:SetDuration(chargeDuration)
```

`EvaluateTotalDuration` 在原生层完成曲线计算；[BaseTime](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectSharedDocumentation.lua) 不受对象 mod time 的加速/减速影响，RealTime 用于实际倒计时。[SetAlpha](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua) 明确允许 tainted 调用方传入秘密参数。曲线结果不在 Lua 中比较、运算、拼接、序列化或反读。

没有采用 `curve:Evaluate(secretCurrentCharges)`：目标 [LuaCurveObject 声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaCurveObjectAPIDocumentation.lua) 的该参数限制为 `AllowedWhenUntainted`，不是普通插件直接传秘密次数的许可。所核查的 Spell / SpellBook / ActionBar / CooldownViewer 声明中未找到专门的公开“充能已经耗尽”谓词。

## 可见性边界依据与限制

下表是指定 build 的基础数据，**不是用于制作倒计时的常数**：

| 技能 | 普通两次使用间隔 | GCD | 基础充能 | 基础恢复周期 |
| --- | --- | --- | --- | --- |
| Blink 1953 | 0.5 秒 | 1.5 秒 | 1 | 20 秒 |
| Shimmer 212653 | 0.5 秒 | 0 秒 | 1 | 30 秒 |

来源：[Blink 数据](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L220)、[Shimmer 数据](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L4737)、[生成字段定义](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/dbc/spell_data.hpp#L459)。Shimmer 没有 GCD 仍有短暂技能间隔；因此“普通 cooldown 非零”不是充分条件。

实现从当前客户端全局 `GetSpellBaseCooldown` 查询两个支持 ID 的普通 cooldown/GCD 元数据，校验为公开、有限且非负的数值，并且要求这些值的最大值**恰为已核查的 1500 毫秒边界**。通过后使用 `(boundary + 1) / 1000`，即此边界再加 **1 毫秒**作为 step curve 的显示分界，并缓存曲线。1 毫秒仅用于排除恰等于普通间隔/GCD的边界，不是计时、延时或施法推算。缺少接口、返回值秘密/异常或最大值不符时，多充能受限分支报告 `Restricted / blocked: native charge visibility` 并隐藏；不会把更长的回复周期当作分界，也不会偷偷回退到固定 1.6 秒。

这个全局 API 不在上述生成的 C_Spell 文档中，其目标客户端存在性和实际返回语义仍需运行时能力检查和验收。如果该客户端对充能技能返回20/30秒回复周期、所有元数据均返回0或其他不符合该边界的元数据，这条多充能受限路径会被明确阻止。**不能宣称此返回行为已经在用户客户端验证，也不能把此降级当作已完成战斗支持。** 普通可读次数与有效单充能恢复路径不依赖此曲线元数据检查。实现没有按 build 硬编码放行；诊断记录实际 build，能力/返回值检查决定能否运行，仍需对该 build 验收。

曲线输入是**总 BaseTime**，不是剩余时间。否则真实恢复只剩 0.2 秒时会错误隐藏。公开元数据产生的分界只用于区分短间隔与恢复周期，不读取秘密计时来创建曲线。

已查看的同 build 修改包括 [Flow of Time 的 -3 秒](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L9274)、[Improved Blink 的 -2 秒](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15370)、[Bronze 的 -15%](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt#L5246)、[额外充能天赋](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15195)及 [Time Walk 重置](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15232)。这些基础周期缩减仍与 0.5/1.5 秒间隔有区分，但不能证明所有旧内容机制或未来热修。

**尚未由真实客户端证明的关键条件：** C++ 普通 cooldown 对象在还有次数时必须反映零/短间隔，在耗尽时必须反映真实恢复周期的总时长。特别是最后一次消耗发生在第一轮恢复只剩不到 0.5/1.5 秒，或受到冷却缩减/恢复变化时，文档没有保证它怎样选择对象。如果对象改为短剩余间隔或一个低于分界的真正恢复周期，这条多充能受限路径可能漏报；若它在仍有可用次数时返回长恢复周期，则可能误报。不能通过离线 mock 把这个未确定语义变成已验证事实，必须按验收表检查。

## 显示、生命周期与固定职业色

live 的父框体透明度由原生显隐路径独占写入；原生 DurationTextBinding 只拥有子 FontString 的时间文字，不覆盖父框体 alpha。样式更新不写 live alpha。非曲线路径显式恢复普通透明度，避免复用到上一次受限透明度。持续提醒的刷新不先逐次 Hide/清空 binding，只有已失效或被 Preview 抑制的条目才清理。

`PLAYER_REGEN_DISABLED` 停止 Test Mode 和品牌装饰动画；不会停用 Mobility 事件监控。关闭 Options 或停止 Preview 会恢复/刷新 live，而不是卸载 live 事件或解除仍有效的真实计时。Preview 与 live 分池。模块继续使用原有事件和一次性事件合并任务，不新增常驻扫描或每帧 Lua 查询。

名称与数字通过统一提醒样式使用当前玩家 `UnitClass("player")` token 的 `C_ClassColor.GetClassColor`，用 `SetTextColor` 施加，按需缓存。无有效颜色时使用安全备用色，初始化后恢复职业色；不保存角色 RGB 到账号配置，不修改全局颜色或字体对象。复用框体、重新应用字体和 Preview 均走同一函数。Options 普通标签、TEST 标记和顶部艺术字保持自身用途的颜色。没有颜色选择器或颜色模式设置。

所有实际时间都来自本次 API 查询的 DurationObject；不读取秘密数字/输出文本，不使用施法历史、手工计次、战斗前快照、固定恢复周期、UI 反读或错误探测。接口缺失、学习/替换异常、对象不可用等分支保留明确降级；这些分支不会被描述为已完成战斗支持。
