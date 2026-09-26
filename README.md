# CarGOUI Alpha 0.1

独立、轻量的 WoW Retail AddOn，当前版本 `0.1.0-alpha.6`，目标为 Retail 12.1.0（Interface `120100`）。本次增量修复法师 Blink / Shimmer 的战斗显隐路径，并统一使用暴雪职业色；保留独立 Options、外部 Test Mode 与现有品牌标题。

**战斗修复已编码，真实战斗验收待完成。** 不再因 `currentCharges` 为 secret 一律退出：一次容量使用公开的恢复活动状态，多次容量使用普通冷却 DurationObject → 原生总时长曲线 → `SetAlpha`；数字单独绑定正在进行的充能恢复。多充能分支诊断为 `Native tracking`，不声称 Lua 知道实际显隐。该路径的短间隔/GCD 边界有 build 69933 技能数据依据，但普通冷却对象在临近恢复、冷却缩减时的选择语义仍需实机验证；元数据或接口不符合前提时继续明确降级。详见 [本轮 API 核查与限制](docs/Mobility-Combat-API-Audit.md)。用户已验证 alpha.5 战斗外可用、战斗内不显示；这不代表 alpha.6 已获客户端验收。

`/cui` 是主命令，打开或关闭 Options；`/cargoui` 保留为兼容别名。当前阶段统一使用英文界面，包括 zhCN 客户端。中文文案保留但未启用，没有语言切换选项。

## 安装

1. 完全退出 WoW，将安装包中的 `CarGOUI` 文件夹放入 `_retail_\Interface\AddOns\`。
2. 确认路径为 `_retail_\Interface\AddOns\CarGOUI\CarGOUI.toc`，不要多嵌套一层目录。
3. 启动游戏，在插件列表启用 CarGOUI，登录后输入 `/cui`。

从 GitHub 下载分支 ZIP 时，将解压后的仓库文件夹重命名为 `CarGOUI`。升级时替换插件文件；**不要删除 WTF 中的 CarGOUI SavedVariables**，原设置会保留并补齐新字段。登录时没有静态占位文字；已学支持技能且满足耗尽条件时自动显示真实提醒，不需要打开 Options 或 Test Mode。

## 法师真实位移提醒

- 只查询 Blink `1953` 和 Shimmer `212653` 的学习状态、当前替换及冷却/充能；Shimmer 已学且替换关系一致时优先，否则监控确认生效的 Blink。未学任何支持技能不显示；学习/替换结果冲突报 `Unknown`，超出范围的替换报 `Unsupported`。
- 有至少一次可用就隐藏；普通可读的次数恰为零时，使用当前正在进行的充能 DurationObject 显示 `No Blink` 或 `No Shimmer` 加真实剩余时间。中途消耗最后一次不会重开完整倒计时，恢复一次立即按游戏状态隐藏。
- 次数受限且容量大于一次时，原生显隐使用包含 GCD 的普通冷却对象的总 BaseTime；计时仍用充能对象的剩余 RealTime。经过校验的两技能普通间隔/GCD 元数据上界是 1500 ms，曲线从其下一毫秒起可见，用于排除精确边界，并非倒计时估算。若 `GetSpellBaseCooldown` 返回受限/缺失/不同上界，报 Restricted；不会将长 CD 当作可用的短间隔边界。
- 非充能技能使用排除 GCD 的自身冷却 DurationObject。法力不足、沉默、距离或施法失败不作为耗尽条件；次数上限不写死为两次。
- 三个法师专精和未选专精的法师均有位置配置。关闭 Options、停止 Test Mode 后，真实模块继续工作。
- Mobility 的 `Enable Mobility` 默认开启。General 的 `Show reminders (live and test)` 是全局开关；关闭任意一个会停止真实显示。
- 提醒名称和数字固定使用当前玩家的暴雪职业色。live、外部 Preview 及后续共用提醒组件统一调用 `SetTextColor`；不提供颜色选择器或 RGB 配置。法师切换专精不变色，换职业按当前 token 取色；初始化暂未取得颜色时用白色，后续样式/进世界事件重试。不改 TEST 标签、普通 Options 文案或品牌艺术字。

在 Mobility 页可查看自动识别技能、状态、调整当前区域 X/Y，跳转全局位置/缩放与字体设置，测试当前技能样例或复制诊断。`Copy diagnostics` 打开只读快照，点击 `Select all` 后按 Ctrl+C；需要新状态时点击 `Refresh snapshot`。诊断含实际 `GetBuildInfo()`、职业/专精、所选接口和限制原因，不保存或序列化秘密计时/次数。

| 状态 | 含义 |
| --- | --- |
| Ready | 普通可读次数确认至少一次可用，或确认没有自身冷却 |
| Depleted | 公开零次或单次容量正在恢复；确认耗尽/自身冷却，使用原生真实计时 |
| Native tracking | 多充能次数受限，原生曲线管理显隐；Lua 不读取结果，不等于已知 Ready 或 Depleted |
| Tracking | 非充能计时状态受限，由原生绑定决定空/过期文本；不是假定 Ready |
| Not learned | 未学支持技能 |
| Restricted | 无法建立安全原生路径，如缺少显隐 API、元数据受限/不符合已核查边界；隐藏输出并给出原因 |
| Unknown / Unsupported | API 暂无有效返回，或缺少接口/遇到不支持的职业或替换；不会当作零次 |
| Disabled | Mobility 或全局显示被关闭 |

## Options 操作

窗口保留左侧分类、右侧选项布局。只有顶部品牌标题区域可以拖动；窗口始终限制在屏幕内，位置单独保存。输入框、滑块、下拉菜单和按钮不会触发窗口拖动。General 中的 `Center window` 可将设置窗口恢复居中。

| 分类 | 可用功能 |
| --- | --- |
| General | Show reminders (live and test)、全局 X/Y、缩放、Animated title、Center window |
| Font & appearance | 字体、字号、描边、阴影 |
| Test Mode | 选择当前专精的提醒区域、Test selected、Test current spec、Stop test、所选区域独立 X/Y |
| Mobility | Enable Mobility、识别技能/状态、当前位移区域 X/Y、样式入口、Test current spell、Copy diagnostics |

普通数字设置没有 Apply 按钮：

- X/Y 输入框：在任意一框按 **Enter**，一起校验并提交当前两个值；一个无效时两个都不修改。
- Scale / Font size：拖动滑块立即生效；精确输入数值后按 **Enter** 生效。
- Region X/Y：在任意一框按 **Enter**，一起提交所选提醒区域的独立偏移。
- 未按 Enter 的文本不会保存。关闭窗口或切换分类会丢弃待提交内容，再次打开显示已保存值。
- 无效数值显示英文错误提示，不改变已保存设置。勾选框、下拉选项立即生效。

全局 X/Y 在各提醒默认锚点上共同平移；Region X/Y 只调整所选条目。正 X 向右、正 Y 向上，范围均为 -10000 至 10000，单位为 UIParent 界面坐标。字号 8–72，缩放 0.5–3；滑块步长分别为 1 和 0.05，输入框允许精确数值。改变缩放不会放大已设定的偏移。

字体使用游戏内置 Friz Quadrata、Arial Narrow、Morpheus、Skurri；不同的客户端标准字体会作为 `Client default` 提供。默认 Friz Quadrata、24 号、普通描边、缩放 1、阴影开启。

`Reset global offsets` 只重置全局偏移，`Reset region offsets` 只重置选中区域。`Reset all settings` 需要再次点击 `Confirm reset`，会恢复包括窗口位置和 Animated title 在内的全部默认配置。

**可拖动的是 Options 设置窗口。游戏空间中的提醒与区域引导不能拖动，没有 Unlock Mode 或布局编辑器。**

## 外部 Test Mode

Test Mode 在实际游戏 UI 空间显示模拟内容，不再在面板内显示静态单词样例。可将 Options 拖到旁边查看外部提醒。

1. 在 Test Mode 选择当前专精的一项条目，点击 `Test selected`；或点击 `Test current spec` 显示当前专精全部已定义条目。
2. Mobility 样例按当前识别技能显示 `No Blink` 或 `No Shimmer`，时间固定为 `8.0`，并明确标记 TEST。Proc 主体只显示固定倒计时数字，不装饰成带图标、技能名称的大框。
3. 测试期间显示淡化的暴雪形状、区域标记等引导，帮助识别正在调整的 Proc 位置。Proc 引导固定在原版区域，偏移只移动计时数字。这些引导仅用于测试，不属于最终实时计时器设计。
4. 修改全局 X/Y、字号、缩放、字体、描边、阴影或所选区域 X/Y，会立即作用于正在显示的外部样例。可切到其他设置页继续调整，不会停止测试。
5. `Stop test` 或关闭 Options 会移除所有样例及引导，并重新查询当前真实状态。重新打开窗口不会自动恢复测试。General 的 `Show reminders (live and test)` 同时控制真实提醒与样例。
6. 正在预览同一位移区域时暂时隐藏该区域的 live 输出，后台真实状态仍同步。进入战斗自动停止 Test Mode，战斗中不能重新启动模拟预览，真实位移模块继续工作。Proc 单条预览不会覆盖另一区域的真实 Mobility。

当前模拟条目：

| 专精 | 已定义模拟条目 |
| --- | --- |
| Arcane | 当前 Blink / Shimmer；Clearcasting 左、右区域 |
| Fire | 当前 Blink / Shimmer；Hot Streak 左、右区域 |
| Frost | 当前 Blink / Shimmer；Fingers of Frost 左、右区域；Brain Freeze 上方区域 |
| 法师未选专精 | 当前 Blink / Shimmer 位移区域 |

同一效果的多个视觉区域有独立条目与独立偏移。Proc 默认定位对应原版暴雪指示器区域，绝非全部堆在屏幕中央；其他插件若移动或缩放暴雪指示器，需要通过区域偏移另行校准。区域几何和客户端数据来源见 `Database/PreviewEntries.lua` 与 [实现说明](docs/IMPLEMENTATION.md)。更换专精时更新可用目录；没有定义条目的职业/专精会明确提示并禁用测试操作。

这些仍是固定模拟样例；技能名称可以跟随识别结果，但 `8.0` 不是实时计时。Proc 目录不判断真实 Buff，其 `sourceSpellID` 只记录图形来源。模拟状态与 live 状态、显示通道独立，不写入 SavedVariables，也不用于判断技能已学或耗尽。

## 标题与品牌素材

Options 顶部已接入参考用户 Logo 制作的透明小徽记与独立 `CarGOUI` 艺术字纹理：Car 为金色，GOUI 为冰蓝色，右侧安静显示 Options / 版本。字标保持约 196.25 × 44、徽记 40 × 40 UI 单位，不随提醒字体、字号或缩放变化。

General 的 `Animated title` 默认开启。原生动画组让约 18% 字标宽度的高光在字形遮罩内移动：1.5 秒扫光、5 秒静默，总周期 6.5 秒。主体不移动、缩放或闪烁。关闭开关、关闭窗口或进入战斗会立即停止并清除高光，静态艺术字和徽记保持不变。只有脱战后窗口仍可见且开关开启才恢复。

若客户端无法创建字形遮罩，模块明确降级为同一字形高光层的轻微 Alpha 呼吸，标题提示 `Glyph pulse fallback`；不使用无蒙版的矩形扫光。用户已在游戏中查看上一版界面并认可大致效果；这不代表本轮真实技能、战斗或全部视觉条件已验收。

`Media/Branding/` 包含四张游戏用 TGA，共 606,280 字节（约 592.07 KiB）；4 个装饰 Texture、1 个 MaskTexture、1 个循环 AnimationGroup。文件大小不是运行内存或性能保证。制作源 PNG、提示词和生产清单保留在仓库的 `source/`，不放入安装 ZIP。本轮未制作 Curse 宣传内容。详见 [素材与来源说明](Media/Branding/README.md) 和 [标题实现与验收](docs/BRANDING.md)。

## 实现状态与性能

| 状态 | 范围 |
| --- | --- |
| 已实现 | 初始化、事件管理、共享 SavedVariables/校验、独立英文 Options、Enter 提交、窗口位置保存、品牌标题与动画开关 |
| 已实现，待客户端验收 | 两个法师技能识别、公开次数/单次恢复路径、多次受限原生显隐、真实计时、事件同步、固定职业色、Mobility 设置与诊断 |
| 条件受限 | 多充能原生分类的实际客户端语义仍待验收；接口/元数据无法满足前提时 Restricted；其他必要 API 缺失时 Unsupported |
| 仅模拟 | TEST 标记的固定 `8.0` 样例；Proc 位置和形状引导 |
| 尚未实现 | 真实 Proc / Buff、其他职业、Evoker Free move、其他真实技能、职业主题、导入/导出 |

Mobility 分类现已可操作。Proc、Themes、Import / Export 保持 `Not implemented` 并禁用。

配置仍只有账号级 `CarGOUIDB`：`position` 是全局提醒偏移，`reminders[id].position` 是各区域偏移，`options.position` 是设置窗口位置，`options.animatedTitle` 控制标题动画；schema 3 新增 `mobility.enabled`。所有持久化修改共用 `UpdateSettings(patch)`。沿用三个专精已有的 `mage_*_shimmer` 位置 ID，同一专精切换 Blink/Shimmer 不重置位置；新增 `mage_unspecialized_mobility`，保留旧 Proc、窗口位置及未知字段。不保存实时次数、计时、DurationObject 或秘密值。

Options 首次打开才创建，后续复用。关闭只停止样例、标题动画及面板临时订阅；启用的 Mage live 模块保留所需状态事件。每个事件突发最多挂起一个可取消的 `C_Timer.NewTimer(0, ...)` 同步任务，没有重复轮询或 Lua OnUpdate。倒计时由原生文本绑定以 0.1 秒间隔更新；关闭模块、显式隐藏框体或被样例抑制时停用绑定。`Native tracking` 的原生透明度为零时仍继续绑定，因为 Lua 不反读显隐结果。不会按每个跳秒刷新 Options 或重启标题动画。WoW 在 `/reload`、登出或正常退出时将 SavedVariables 写入 WTF。

## 游戏内验收

本轮步骤见 [战斗与职业色验收](docs/Mobility-Combat-Acceptance.md)：需在城镇、木桩战斗及实际副本战斗验证两种技能、恢复一层、中途再耗尽、临近恢复才耗尽、GCD、冷却缩减/重置、预览隔离及职业色。此前 [Phase 2A 基础验收](docs/TESTING_MOBILITY.md) 保留作历史与识别回归参考。以下保留交互回归步骤。建议先只启用 CarGOUI，并使用 `/console scriptErrors 1` 开启错误弹窗。

1. 登录后用 `/cui` 开关窗口，再验证 `/cargoui` 相同行为。`/cui help` 显示帮助；zhCN 客户端的界面和提示仍为英文。
2. 拖动标题到屏幕侧边，关闭重开、`/reload` 后确认窗口位置保留。尝试操作各输入框、滑块、菜单，窗口不应跟着拖动。
3. 全局 X 输入 100、Y 输入 -80，在任一框按 Enter。确认两值同时保存。输入一个无效轴再按 Enter，确认两轴均未改变。
4. Scale 和 Font size 分别测试滑块与数字 Enter。输入数值但不按 Enter，关闭重开，应恢复保存值。
5. 在法师当前专精选 Test Mode，分别启动单条与全部样例，将窗口移开查看外部提醒。调整外观、全局偏移及区域偏移，检查对应变化。
6. 检查多区域 Proc 的位置和独立条目，确认数字居于目标指示形状的视觉中心；检查实际 UI 缩放与分辨率下的字体和形状。
7. 切换专精，确认目录与样例更新。停止测试、Esc、Close 或 `/cui` 关闭后，应无样例、引导或残留菜单；重新打开不自动测试。
8. 开关 Animated title：确认静态字标始终清楚，开启时高光仅扫过字形，静默阶段无残影；关闭立即清除高光。战斗中静止，脱战仅在窗口仍可见且开关开启时恢复。反复开关窗口 20 次，检查拖动、关闭、预览和输入焦点仍正常。
9. 测试重置确认、隐藏样例、配置重载保留；反复开关窗口应无 Lua 错误。

本轮保留原交互、品牌与 Preview 覆盖，并新增真实位移状态、事件、secret/nil/API 缺失、迁移及模拟隔离测试。最终用例数量、结果、ZIP SHA256 和解压包复测输出见交付测试报告；不能用仓库测试代替最终安装包复测。

**本轮真实技能未进行游戏内实测。** 离线模拟不能完整复现 WoW secret value、taint、原生渲染和战斗限制。开发者可运行 `python tests/run_tests.py` 或 `lua5.1 tests/smoke.lua .`。运行器使用已有 Lua 5.1/LuaJIT 或 `lupa.lua51`，不会自动安装依赖。

## 文件与兼容命令

核心仍在 `Core/`、默认值/英文文案/命令在 `Config/`。`Database/MobilityEntries.lua` 是两个真实技能及兼容位置 ID 目录；`Modules/Mobility/SpellState.lua` 负责 API 边界，`Runtime.lua` 负责事件与真实状态。`UI/ReminderStyle.lua` 负责按职业 token 缓存、应用和恢复职业色，不写 SavedVariables。`UI/Display.lua` 共用布局/字体，但真实计时走单独原生绑定入口，绕开模拟字符串拼接与测量；父框体原生透明度只有此入口写入，不被字体刷新覆盖。`UI/Options.lua`、`UI/Preview.lua`、`UI/Branding.lua` 分别管理交互、模拟及标题；TOC 按依赖顺序加载。详见 [实现说明](docs/IMPLEMENTATION.md)。

命令主入口均为 `/cui`，`/cargoui` 完整兼容：`help`、`status`、`show`、`hide`、`position <x> <y>`、`font <friz|arial|morpheus|skurri|default>`、`fontsize <8-72>`、`outline <none|outline|thickoutline>`、`scale <0.5-3>`、`shadow <on|off>`、`reset`。日常操作可全部在窗口完成，`reset` 命令会立即重置。
