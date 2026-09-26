# Phase 2A — Blink / Shimmer API 核查

本次只核查 Blink `1953`、Shimmer `212653`。目标声明为 **Retail 12.1.0 / build 69933 / Interface 120100**，Blizzard UI/API 声明镜像固定到 [`09b9db7948abc9b9648dedaab51eb0cf3ee67b31`](https://github.com/Gethe/wow-ui-source/tree/09b9db7948abc9b9648dedaab51eb0cf3ee67b31)。用户实际客户端 version/build **未知**；TOC 不是实测证据。Options → Mobility → Copy diagnostics 显示运行时 `GetBuildInfo()` 的 version、build、date、Interface。

## 采用的识别和判断

`C_SpellBook.IsSpellKnown(spellID, spellBank = Player) -> bool` 分别检查两 ID；`C_Spell.GetOverrideSpell(spellIdentifier, spec = 0, onlyKnown = true, ignoreOverrideSpellID = 0) -> number` 解析当前已知替换。默认 spec 为当前专精，无替换时返回原 ID。选择 Shimmer 必须同时满足：已学 Shimmer、Blink 当前替换为 212653、Shimmer 自身仍解析为 212653；否则仅在未学 Shimmer且已学 Blink、Blink 仍解析为 1953 时选择 Blink。学习和替换结果不一致时报告 Unknown，等待新的真实事件同步，不猜测当前生效者。解析结果超出支持的替换时为 Unsupported。没有专精不阻止查询。

`DoesSpellExist` 只表示法术资料存在；`IsSpellInSpellBook` 也可能包含未学替换技能，因此二者都不用作已学依据。来源：[学习声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua#L666)、[替换声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L165)。具体等级、天赋充能上限不硬编码，仍需客户端验收实际替换关系。

| 来源 | 实现中的使用与边界 |
| --- | --- |
| `C_Spell.GetSpellCharges(spellIdentifier) -> SpellChargeInfo?` | 验证实际 maxCharges；普通可读 currentCharges >= 1 隐藏，恰为 0 且有效 recharge 才显示。nil 本身不是 Ready 或零次。 |
| `SpellChargeInfo.maxCharges / isActive` | 声明为 NeverSecret；isActive 仅表示正在充能，不能证明耗尽。 |
| `currentCharges / cooldownStartTime / cooldownDuration / chargeModRate` | 可能受限。代码先检查 `issecretvalue`，不对秘密次数比较/算术；不自行运算充值时间字段。 |
| `C_Spell.GetSpellCooldown(spellIdentifier) -> SpellCooldownInfo?` | nil charges 时还要求有效 cooldown record 且 isEnabled 为 true，避免将无数据解释为就绪。 |
| `SpellCooldownInfo.isEnabled / isActive / isOnGCD` | 声明为 NeverSecret；isOnGCD 只保证在响应 SPELL_UPDATE_COOLDOWN 时可信，因此实现不依赖它做延迟或重载判断。 |

这些表 API 带 `MayReturnNothing` 和 `SecretWhenCooldownsRestricted`。但单个技能的 never/always-secret 标记可覆盖通用限制，不能据此宣称两个技能在战斗中必然受限，也不能假设自身技能始终可读。来源：[Spell API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L250)、[字段秘密性](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua#L6)、[限制规则](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua#L89)。

## 实际计时与渲染路径

1. 充能已确认耗尽：`C_Spell.GetSpellChargeDuration(spellIdentifier) -> LuaDurationObject?`，直接取**已经进行中的下一次充值**，不从最后一次施法重新起算。
2. 非充能技能：`C_Spell.GetSpellCooldownDuration(spellIdentifier, ignoreGCD = false) -> LuaDurationObject?`，实现传 `true` 排除纯 GCD，不用时长阈值猜测 GCD，也不使用可施法性、法力、距离或失控条件。[两种 Duration API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L233)。
3. 对象句柄必须普通可访问；对象**内部计时可以受限**。`duration:IsZero() -> bool` 的结果先查秘密性：公开 zero 可确认非充能 Ready，秘密结果不分支，交给原生显示。充能数为零却只有公开 zero duration 时报告 Unknown，等待真实事件重新同步。
4. `UI/Display.lua:RenderLiveMobility` 使用原生 DurationTextBinding。布局尺寸来自普通配置 `font.size * 16`、`font.size * 3`，共用位置/字体/缩放；不进入 Preview 的拼接、空串比较、文字宽高测量路径，不读取原生输出文本。

本版实际使用的完整方法与静态参数：

```lua
binding = C_DurationUtil.CreateDurationTextBinding()
formatter = C_StringUtil.CreateNumericRuleFormatter()
formatter:AddBreakpoint({
    threshold = 0, step = 0.1,
    rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f",
})
binding:SetFontString(fontString)
binding:SetTextFormat("No " .. publicSpellName .. "\n{}", {
    { property = Enum.DurationTextBindingProperty.RemainingDuration,
      formatter = formatter },
})
binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
binding:SetUpdateInterval(0.1)
binding:SetExpiredText("")
binding:SetZeroDurationText("")
binding:SetDuration(durationObject)
binding:Enable()
binding:UpdateFontString()
-- When hidden / disabled:
binding:Disable()
binding:SetToDefaults()
```

`publicSpellName` 只来自本插件两项静态目录。RealTime 让客户端按实际计时倍率计算；向上舍入至一位小数，避免尚未恢复时先显示 `0.0`。原生 empty expired/zero 文本清除整段提示；实际 Ready/重置状态仍以新 API 同步为准，不用自制计数或定时归零判断恢复。来源：[binding](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingObjectAPIDocumentation.lua)、[格式组件](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingSharedDocumentation.lua)、[数字规则](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericRuleFormatterSharedDocumentation.lua)、[时间倍率](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectSharedDocumentation.lua)。

## 精确限制，不能当作完整战斗支持

**`currentCharges` 为 secret 时，无法证明零次可用：状态为 Restricted，live 输出隐藏。** 已核查原生布尔透明度/颜色映射，它们不能从秘密数值生成“次数恰为零”；充值 isActive 也无法区分 1/2 与 0/2。普通 cooldown 不保证排除“尚有次数但存在两次施法间冷却”的情形，不能作为零次数替代。Blizzard [CooldownViewer 的充能优先逻辑](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua#L909) 不能证明这两个技能所有场景的具体行为，也不能授予插件读取秘密次数的权限。

这与“次数公开为零、计时对象内部受限”不同：后者走原生展示，仍可工作。非充能内部时间受限时报告 Tracking，由原生 binding 处理 active/zero/expired；不会在 Lua 中判它 Ready。缺少已学/替换、secret 检查、Duration 或 native binding API 时明确 Unsupported；nil/异常状态报告 Unknown。不使用 pcall 错误探测、UI 反读、施法记录、固定冷却、手工计次或旧快照推算。

## 事件、生命周期与诊断

模块只为启用的法师监听下列事件；每次最多查询两个候选技能，不扫描法术书/Buff：

| 事件 | 已核查参数 |
| --- | --- |
| SPELL_UPDATE_CHARGES / SPELLS_CHANGED | 无参数 |
| SPELL_UPDATE_COOLDOWN | spellID?、baseSpellID?、category?、startRecoveryCategory?、itemID?；nil spellID 表示全体。实现只合并事件并重新读两技能，不用事件秘密字段运算。 |
| PLAYER_SPECIALIZATION_CHANGED | unitTarget；仅处理 player |
| PLAYER_TALENT_UPDATE / PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED | 无参数 |
| TRAIT_CONFIG_UPDATED | configID；用于触发重新识别 |
| PLAYER_ENTERING_WORLD | isInitialLogin、isUIReload |
| PLAYER_ALIVE / PLAYER_DEAD / PLAYER_UNGHOST | 无使用参数；重新同步 |

来源：[SpellBook 事件](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua#L853)、[Unit 事件](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L3759)、[天赋](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua#L443)、[Trait](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua#L808)、[进世界](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Game/Shared/EventImplementation.lua#L297)、[死亡复活](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Game/Mainline/EventImplementation.lua#L221)。

`C_Timer.NewTimer(0, callback)` 仅合并一批事件为一个可取消的下一轮同步任务，不循环、不无限重试。native binding 的 0.1 秒间隔只更新原生文字，不重新扫描状态。禁用时取消挂起任务、解绑模块自己的回调并清空 live；不会删除品牌/Preview 的同名事件回调。关闭 Options 保留 live。开始同条目 Preview 只抑制 live 渲染；结束后重新查询 API。进入战斗停 TEST，保留真实监控。

诊断使用显式公开字段白名单，不记录原始充能表、DurationObject、原生文字或账号信息。SavedVariables 保留原位置并只新增 `mobility.enabled` 和未选专精位置。最终离线/解包测试结果见交付测试报告；**游戏内真实技能、secret/taint 及原生显示尚未实测**，验收步骤见 [TESTING_MOBILITY.md](TESTING_MOBILITY.md)。
