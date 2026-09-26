# alpha.13 增量升级与用户复测

基线：alpha.12，提交 `74d452516c1ce78ef213128133f95616f5df7707`。本轮只修复 Clearcasting 接入并添加 Proc 逐区域 RGB，没有扩展其他职业真实 Proc、特殊 Mobility 或主题。

## 安装

1. 完全退出 WoW，备份现有插件程序目录后，把交付 ZIP 中的 **CarGOUI + CarGOUI_Data** 两个文件夹替换进 `_retail_/Interface/AddOns/`。
2. 检查两个目录分别直接包含同名 TOC，版本均为 `0.1.0-alpha.13`。如果仍有旧的 `AddOns/CarGOUI_Mage`，仅移除那个旧程序目录，避免重复旧包。
3. **不要删除 WTF、CarGOUIDB 或任何 SavedVariables。** Schema 5 不变，Clearcasting 左右区域 ID、现有坐标、共用字体、Mobility、Options 窗口位置及品牌开关保持。
4. 新字段只有当前 Proc 区域可选 `color={r,g,b}`。未自定义时该字段保持不存在，动态回退当前职业色。已有有效 RGB 独立复制，错误 RGB 安全回退；不把账号所有职业重新初始化。

## Clearcasting 修复内容与证据边界

alpha.12 只接受旧图形 owner `276743` 并把它也当计时 Aura。目标 build **69933** 中另外存在三个新的 Clearcasting 图形 owner：`1277420 / 1277421 / 1277422`。它们是无限时长 Dummy 图形载体，不能作为真实剩余时间来源；之前遗漏这些 SHOW 事件也可能让区域一直停留在旧的 HIDE 状态。

本包只用真实有限时长 Aura **263725** 作为原生计时过滤器，单独处理三个新图形 owner。换图形保持原左右区域和原生绑定，旧 owner 的 HIDE 不会清掉已经显示的新 owner。不混入 276743、277726 或三种图形 Dummy 作为可任选的候选计时，不读层数、不计施法、不写固定持续时间。

关联依据包括目标 DB2、暴雪对 Clearcasting 图形显示层数的官方说明，以及当前法师实现中实际 Clearcasting Aura 的使用。**这是有来源支持的映射关联，未直接观察用户客户端的事件，也没有公开的完整服务端关联代码。** 本包实现及离线测试通过不代表实机已经修好。完整依据见 [CLEARCASTING_ALPHA13.md](CLEARCASTING_ALPHA13.md)。

用户已反馈 **Arcane Soul 与 Overpowered Missiles 在其 alpha.12 场景正常**。这两项保持原映射，记录为对应场景的用户证据；其他 Proc、其他场景没有因此被标记通过。

## 先复测真实 Clearcasting

关闭 Test Mode，启用暴雪原生 Spell Alert，确认透明度非零。

1. 正常触发 Clearcasting，左右数字应出现在各自原生图形的视觉中点，沿用已保存偏移。
2. 增加和部分消耗层数，观察不同图形切换：还有增益时不能因上一图形隐藏就清空全部数字。剩余时间应来自真实 Aura，不能重开固定完整时间。
3. 刷新持续时间、最后一次消耗、自然到期分别检查；在战斗内外重复。
4. 同时触发 Arcane Soul、Overpowered Missiles，确认各自计时不串联；关闭 Options、停止 Preview 后真实计时继续。
5. 已有增益时 `/reload`，再切专精返回，确认真实状态重新同步，原坐标/字体/颜色不变。原生图形没有通用历史重播 API，这一步必须实测。
6. 若仍无数字，用原有 **Mobility → Copy diagnostics** 入口，在触发后立即复制一次、消耗后再复制一次。诊断包含真实 build、配置的 Aura/owner、最近 16 条允许记录的图形事件，以及各区域门控/布局/API 原因。不会读取受限 Aura 或子框体，诊断的 Native tracking 也不意味着 Lua 知道 Buff 存在。

## 再复测区域颜色

打开 `/cui → Proc`，用原有 **Proc region** 菜单选条目。色块旁显示具体技能及位置，不以泛称“左/右”区分。

1. 分别给 Clearcasting 左/右选择不同 RGB，再给 Arcane Soul 外左/外右和 Overpowered Missiles 上方设置独立颜色。Buff 不必正在触发，已定义条目始终可选。
2. 点击 **Timer color** 色块。拖动拾色器会实时更新该区域已有的 live / Preview 数字；点原生 **Okay** 才保存。Cancel、Esc、关闭、切区域/专精或离开页面都取消未确认编辑。
3. 点击 **Use class color** 仅移除当前区域自定义 RGB。打开拾色器后不改变颜色直接 Okay，不会把默认职业色写成固定自定义色。没有透明度控件。
4. 在 Appearance 统一改本专精字号、字体、描边、阴影和 Scale，检查所有区域字体一起变，独立颜色/位置不变；Mobility 与 Free move 仍使用职业色。
5. 切 Fire 与 Frost，对现有大小括号、顶部及左右区域分别修改，再切回 Arcane；然后 `/reload`、开关窗口、更新主题，确认颜色恢复正确。
6. 拾色器打开期间切条目/专精、关闭 Options；也可让其他插件后来打开原生拾色器，确认本插件旧回调不会把颜色写入新条目或关闭别人的窗口。
7. 在真实计时进行时反复调色，确认不会重启数字、改变原生门控透明度、清除其他提醒或增加绑定。诊断只统计公开请求/分配数量，不反读秘密显隐。

当前可配置菜单覆盖 **Arcane 5、Fire 7、Frost 3 个区域**。保留在数据中的历史 Fury of the Sun King 仍没有核验的当前天赋来源，仅在真实原生事件时尝试接入，不以可用条目出现在菜单中；本轮不把它冒充已支持的配置区域。未来职业只需提供符合接口的稳定 Proc 区域定义，复用同一颜色机制。

## 回归与交付验证

- 保留 Blink/Shimmer 已通过的战斗路径：可用一次隐藏、耗尽显示下一次真实恢复、恢复一次立即隐藏。普通多技能 Mobility 和 Free move 不被 Proc 颜色影响。
- 同一安装包仍只有两个顶级 AddOn；共享 Data TOC 静态文件和账号 SavedVariables 可能整体载入，不能把未访问表说成未载入。只建立当前必要的业务数据和颜色控件。
- 无新增 OnUpdate、Buff 扫描、后台日志轮询、强制 GC 或大型依赖。公开事件追踪固定保留最近 16 条；原生拾色器 hooks 一次安装，空闲时不处理业务。
- 交付包从已提交源码生成，验证文件内容、TOC、CRC、SHA256；完整测试在**最终 ZIP 解压目录**运行。报告包含实际用例数、三组静态检查、源码树及打包提交。
- 当前开发环境无真实 WoW 客户端。新增 Clearcasting 修复、RGB 交互与视觉位置均待用户复测；不会将离线模拟、目标源码核查或此前其他两个 Proc 的反馈扩写成全套实机通过。
