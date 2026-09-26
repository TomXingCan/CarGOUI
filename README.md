# CarGOUI Alpha 0.1

当前版本 **0.1.0-alpha.14**，在 alpha.13 提交 `7ba1dae6` 上只调整 Options 的战斗打开/关闭生命周期。目标 WoW Retail 12.1.0（Interface 120100），已有数据/API 核查固定 build 69933。Mobility、Free move、Options 格局、主题、Proc 区域颜色、字体范围及用户坐标保留；不扩展其他职业真实 Proc 或已排除的特殊 Mobility。

用户于 2026-09-27 确认当前法师 Proc 正常。本轮保留这份实机反馈和 alpha.13 的映射/颜色实现，不将它扩写为每种天赋、布局或重载场景的逐项验收。其他 12 职业 Proc 仍只处于清单核查范围，没有新增真实监控。历史 [Clearcasting 修复依据](docs/CLEARCASTING_ALPHA13.md)、[法师覆盖表](docs/MAGE_PROC_COVERAGE.md) 保留；本轮见 [战斗锁定说明与验收步骤](docs/OPTIONS_COMBAT_LOCK.md)。

## 安装与升级

1. 完全退出 WoW，把交付 ZIP 中 **CarGOUI 和 CarGOUI_Data 两个文件夹一起**放入 `_retail_/Interface/AddOns/`。这是同一个安装包，内部 Data 包会自动加载，不需要选择职业包。
2. 检查 `CarGOUI/CarGOUI.toc` 与 `CarGOUI_Data/CarGOUI_Data.toc` 都在上述目录下，没有多嵌套一层。
3. 从 alpha.8 升级时，退出游戏后删除旧 **AddOns/CarGOUI_Mage 程序目录**，再替换新包两个目录。**不要删除 WTF 中的 CarGOUI SavedVariables**。插件不会自动删除程序目录或用户存档。所有现有职业配置、Proc 样式、坐标及外壳设置保留。
4. 登录后 `/cui` 打开或关闭 Options；`/cargoui` 为别名。zhCN 客户端也默认英文。

战斗中输入任一别名只排队一次，并提示 `CarGOUI: Options will open when combat ends.`，不会创建窗口、打开拾色器或启动 Test Mode。脱战并确认解除锁定后打开一次；普通脱战不会反复弹窗。窗口已打开时进战斗会自动收起、取消未确认编辑并停止 TEST；仅自动收起不会排队重开。待处理请求只存于当前会话，重载/登出不保留；`help`、`status` 行为不变。

从 GitHub 源码安装时：仓库主体作为 `CarGOUI`，另将其中 `Modules/CarGOUI_Data` 复制为 AddOns 下的同级 `CarGOUI_Data`。推荐直接使用交付安装 ZIP，避免遗漏内部模块。

## 配置范围

| 设置 | 归属 |
| --- | --- |
| Mobility 开关、字体、字号、描边、阴影、缩放、锚点、XY、偏好 | 当前 classToken，共用一套；Mage 三系及 Blink/Shimmer 共用 |
| Proc 字体、字号、描边、阴影、文字缩放 | 当前 classToken + specID，同专精所有区域共用 |
| Proc 区域锚点、XY、可选 RGB | 对应职业/专精下稳定区域 ID 分别保存；无自定义 RGB 时动态使用职业色 |
| Options 窗口位置、品牌动画开关 | 插件外壳独立保存 |

没有职业、专精、Profile 或手动 Theme 选择器。Appearance 的原选择字段现在只读显示自动配置上下文。Proc 区域菜单选择位置、预览和颜色对象，不创建区域独立字体。

Mobility 和 Free move 固定使用玩家的暴雪职业色。Proc 数字默认使用职业色，允许各稳定区域分别设置 RGB，没有透明度设置。Options 的阵营/专精主题与提醒颜色、字体、计时无关。

## 操作

Options 仍是左分类、右选项。Header、Body 背景、侧栏空白、边框与静态说明区域均可左键拖动整个窗口。按钮、滑块、输入框、下拉菜单及滚动条保留正常操作，不要求修饰键。松开、关闭或 Esc 结束拖动，位置保存与屏幕约束保留。General 与 Mobility 的开关/XY 都编辑当前职业的同一份 Mobility 配置。关闭 Mobility 也停止 Free move 并隐藏 Mobility 样例，不影响真实 Proc；Proc 页面可独立启停本专精的数字。

Mobility / Proc → Appearance 提供 Font、Font Size、Outline、Shadow、Scale。菜单、勾选框和滑块立即生效；输入数字后按 Enter，没有 Apply。切换上下文、分类或关闭窗口会丢弃未提交输入。`Reset this context's style` 仅重置当前样式，不改坐标或其他范围。

Proc 页面在所选条目旁显示明确的技能/位置名称与 **Timer color** 色块。点击打开原生拾色器，调色实时预览，Okay 才保存；Cancel、关闭、切区域或专精会取消未确认颜色。**Use class color** 只移除当前区域 RGB。字体仍按专精共用；颜色只更新该区域已有 live / Preview 字体对象，不查询 Buff、不重建计时或改动门控透明度。[颜色说明](docs/PROC_COLORS.md)。

`Reset Mobility offsets` 仅重置当前职业位移坐标；`Reset region offsets` 重置当前区域。`Reset class + Options` 需再次确认，只重置当前职业和外壳，保留其他职业和迁移备份。快捷 `reset` 命令仍会立即执行这个同样的范围。

字体内置 Friz Quadrata、Arial Narrow、Morpheus、Skurri（必要时提供 Client default）。工厂样式为 Friz Quadrata 24、OUTLINE、阴影开启、Scale 1。字号 8–72，缩放 0.5–3，新编辑 XY -10000–10000。缩放不会放大已有坐标。

Test Mode 使用外部游戏空间的固定 `8.0` 样例并标记 TEST；Free move 样例只有文字。法师 Proc 菜单复用已核查的当前专精区域。样例与原生 Aura/计时隔离，不向真实槽位写入样例状态。未实现且已移出范围的 Mobility 候选不再进入可选预览。

关闭窗口、Stop test、进战斗或切专精会停止样例并清理旧临时状态。Live 继续按真实 API 更新；正在测试同一区域时只暂时抑制对应 live 输出。提醒和引导不可拖动，没有 Unlock Mode。

## 分层自动主题

Header 只表达阵营：Alliance 蓝色、Horde 红色，中立/未知使用中性回退。同阵营切专精不改变 Header 主色或品牌强调色；原始彩色徽记/字标保持清晰。

Body 只读取职业＋专精，覆盖主体、侧栏及底部操作区。目标版本全部 13 职业、40 专精都有明确配色和图案；同职业专精使用不同成品主题。法师 Arcane 的深紫→奥术紫符文法阵、Fire 的暗红棕→琥珀橙火焰、Frost 的深蓝→冰青冰晶均保持 alpha.9 的原始定义。按钮、输入框、菜单使用同色系层次，普通正文保持清楚。[完整 Body 覆盖表、来源与逐项验收状态](docs/BODY_THEME_COVERAGE.md)。

未选专精使用本职业基础主题，身份暂不可用使用中性回退并在信息恢复事件后更新。打开窗口始终重新解析；隐藏时停止主题监听。关闭 Mobility、尚未学会位移、未加载业务适配器或关闭 Preview 均不影响主题。所有主题定义属于核心轻量 UI 数据，不为显示主题加载全职业业务或创建提醒框体。

图案位于 Body 右下内容背景，使用原创静态几何与原生 Line 的纯色线段绘制；不加载宣传图、不新增图片、粒子或旋转动画。共用线段池只绘制当前图案，身份变化或打开时更新；不承诺游戏纹理缓存立即卸载。Header 与 Body 配色映射独立，提醒颜色、字体、坐标、DurationTextBinding 和显隐不受影响。[分层主题与素材/API 来源](docs/THEMES.md)。

## 真实 Mobility

当前职业适配器只选择本职业、当前专精、实际学习且生效的技能。替换技能归入同一技能族，不重复显示。各技能使用独立的状态、提醒框体和原生计时绑定；一个技能恢复不会清掉另一个仍在冷却的提醒。普通冷却使用排除 GCD 的原生对象；充能倒计时始终使用正在进行的下一次充能恢复对象。多充能秘密值的显隐仅使用该技能独立核查的原生曲线规则，没有通用法师阈值。

可读充能至少一次时隐藏；耗尽后显示 `No <Ability>` 与真实恢复时间；恢复一次即消失。不可施法、目标、距离、资源、沉默和控制不作为耗尽。法师 Blink 1953 / Shimmer 212653 的已验证判断主体保持原文件不变。新增原生路径与限制见 [API 核查](docs/MOBILITY_API_AUDIT.md)，原法师记录保留于 [Mage 战斗核查](docs/Mobility-Combat-API-Audit.md)。

`Native tracking` 表示显隐交给原生接口，Lua 不宣称知道最终 Ready / Depleted；`Tracking` 表示原生计时控制零值和到期输出。既有技能路径遇到范围外的条件返回等机制仍保留安全检查并报告 `Unsupported`，未通过规则或元数据校验的秘密多充能分支报告 `Restricted`。不会用样例、固定 CD、施法记录或秘密值反读填补。

每个技能族有稳定的预设槽位；第一个位于原职业 Mobility 锚点，其余按定义向下每槽 84 个 UI 单位排列。不可用技能的空槽不引起其他技能跳位；本职业 XY 一起平移这组槽位。法师 Blink/Shimmer 的原位置 ID、坐标和外观不变。所有技能共享本职业 Mobility 样式，不创建逐技能字体。已有 Test Mode 菜单可选择当前活动技能或同时预览；测试单个条目只暂时抑制该条目的 live。

历史普通 Mobility 实现与逐项限制见 [Mobility 覆盖表](docs/MOBILITY_COVERAGE.md)。范围外机制不再作为开发阻塞项或本轮必测任务。

## 真实法师 Proc 与 Free move

Proc 正式显示仅包含数字，使用该区域自定义 RGB 或默认职业色，放在对应暴雪图形区域的视觉中点。以原生图形根框体的实际缩放/布局、核验的区域几何和 SHOW 事件缩放定位，叠加原有区域 XY；不读取图形子框体的显隐、Buff 或数字，不修改暴雪图形。旧存档的偏移不清空；默认中点由真实原生布局决定，不再以旧样例绝对坐标代替。

奥法覆盖 Clearcasting、Arcane Soul、Overpowered Missiles；火法覆盖 Hot Streak、Heating Up、**Pyroclasm（需读条的炎爆/烈焰风暴增益）**、Hyperthermia；冰法覆盖 Fingers of Frost 左右和 Brain Freeze。保留的 Fury of the Sun King 图形行仅在实际原生 SHOW 事件后接入，不作为当前可用天赋展示样例。图形 ID、Buff ID、纹理、大小和区域分别记录，详见覆盖表。

客户端原生 `CustomAuraContainerTemplate` 以 `HELPFUL + includeSpellIDs` 筛选自身 Aura，在原生侧管理触发、消耗、刷新和到期。数字使用原生复制的 DurationTextBinding；Lua 不查询/比较秘密 Buff、剩余时间或层数。正式显示没有技能名、图标和背景。没有原生 Aura 或原生接口缺失时不制造替代时间。原生图形缺乏通用历史重放接口，重载时使用明确映射的计时 Aura 原生匹配启动（它不一定与图形 owner 同 ID）；相关图形实际出现条件仍列入实机验收。

Free move 的含义已确认是 Time Spiral 374968 赋予的职业接收增益，而非 Hover 的移动施法。原生槽位只匹配当前职业的接收 Aura，真实存在时显示 `Free move`，消耗或到期时消失；不加倒计时，不计施法次数。使用本职业 Mobility 字体和坐标组，固定预设在第一条普通 Mobility 上方 84 UI 单位，不清除其他技能提醒。

关闭 Options/停止 Test Mode/进入战斗不停止真实监控。关闭 Proc 只停用 Proc 槽位与该模块的事件；关闭 Mobility 只停用 Mobility 与 Free move。原生容器停用后以透明但保持显示的公开父容器完成一次原生清理，避免隐藏父框体冻结清理流程。
## 加载、诊断和限制

登录识别当前受支持职业后请求原生按需加载的 `CarGOUI_Data`。同一 Data TOC 列出的文件、静态定义会一起加载；职业子目录本身不具备独立按需加载能力。本轮 13 职业的适配器定义会一起加载，只有当前职业的定义工厂与实际学习筛选执行；不能声称其他职业代码未加载。

明确的职业适配器注册表选择当前职业，禁止多个职业文件依次覆盖核心方法。只有当前适配器运行当前专精/实际生效技能的路径，无无关技能查询、业务监听、提醒框体或计时绑定。重复注册被拒绝。残留旧 `CarGOUI_Mage` 若被加载，旧桥接写入隔离对象，不会覆盖新核心；升级仍应清理旧程序目录。

**架构取舍：统一两个顶级目录不满足此前严格逐职业文件/存档完全不载入的目标。** 核心账号级 `CarGOUIDB` 仍可能恢复所有已保存职业记录；仅当前范围被访问/初始化，并不等于其他记录未加载。配置不删除、不压缩、不强制 GC。实际开销须以客户端测量评估，不能用目录数或 ZIP 大小代替。

Mobility → `Copy diagnostics` / `Refresh snapshot` 现有入口记录四层边界：模块加载状态、活动条目实例、配置载入/访问情况、监听及活动/已分配绑定数量。额外按需读取游戏运行时内存 KB、累计 CPU ms；未开启 scriptProfile 时 CPU 标为不可用。原生 Aura 槽位单独记录分配数/请求启用数；后者不是可见 Buff 数。复制的原生计时绑定状态不反读。无后台采样、强制 GC、全库扫描或轮询。缓存框体和已加载代码不会假称卸载。详见[加载与实机测量](docs/LOAD_BOUNDARIES.md)。

## 迁移和验收

Schema 5 使用 `classes[classToken].mobility` 与 `classes[classToken].proc[specID]`。旧 Mage 配置仅进入 Mage；按实际生效技能和当前位置选择合并值，冲突原值及选择规则保存在 `migrations.scope5`。其他职业首次访问使用深复制的工厂默认值。迁移只补缺失/无效值，不在每次登录覆盖新配置。[迁移规则与验收清单](docs/CONFIG_SCOPES.md)。

离线测试保留战斗秘密值与战斗标志分别模拟的回归，并验证范围隔离、延迟初始化、加载/订阅/绑定有界、主题和草稿行为。交付报告记录**最终 ZIP 解包后的测试**及 SHA256。

**开发环境没有真实 WoW 客户端。** 用户已确认升级前 Blink/Shimmer 及法师 Header/Body 正常；Arcane Soul 和 Overpowered Missiles 也已有用户对应场景正常的反馈。Clearcasting 本轮修复、颜色交互、其他未反馈 Proc/Free move 场景、alpha.11 非 Mage 技能路径、alpha.10 新主题视觉、本包战斗回归及 CPU/内存仍待客户端验收。离线测试只能验证提供的 API 响应下的行为，不能证明客户端所有天赋/热修/秘密值语义。Body 主题覆盖与真实 Mobility 覆盖始终分别记录。

## 源码结构

`Core/`：初始化、事件、配置校验迁移、按需加载、诊断；`Config/`：工厂默认、英文文案、命令；`Database/`：通用样式上下文与主题映射；`UI/`：共用提醒、Preview、Options、品牌/主题；`Modules/Mobility/`：当前活动技能事件引擎与 Free move；`Modules/Proc/`：原生 Aura 槽位与图形事件生命周期；`UI/ProcDisplay.lua`：合法原生位置和字体边界；`Modules/CarGOUI_Data/`：统一 LoD TOC、职业注册、`Shared/` 状态引擎与各 `Classes/` 私有定义/适配器；`tests/`：Lua 5.1 离线测试与静态检查。

运行 `python tests/run_tests.py`、`python tests/check_mobility_static.py`、`python tests/check_styles_theme_static.py`、`python tests/check_proc_static.py`。需要已有 Lua 5.1/LuaJIT 或 `lupa.lua51`，运行器不自动安装依赖。

本轮安装与验收见 [UPGRADE_ALPHA13.md](docs/UPGRADE_ALPHA13.md)。两目录清理和拖动的历史核查见 [UPGRADE_ALPHA9.md](docs/UPGRADE_ALPHA9.md)；主题表保留于 [BODY_THEME_COVERAGE.md](docs/BODY_THEME_COVERAGE.md)。继续保留 WTF / SavedVariables；Schema 5 不变，只在当前区域保存可选 color，不写入职业色默认值或重置现有样式/坐标。
