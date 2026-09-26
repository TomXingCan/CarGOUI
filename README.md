# CarGOUI Alpha 0.1

当前版本 **0.1.0-alpha.10**，目标 WoW Retail 12.1.0（Interface 120100）。本次增量补齐 **13 职业、40 专精的 Body 主题**，包括 Devourer；保留用户已实测通过的法师主题、阵营 Header、全面板空白区域拖动及 Blink / Shimmer 战斗路径。继续使用 CarGOUI + CarGOUI_Data 两个安装目录。本次主题覆盖与技能监控覆盖分别记录：此源码目前仍只有法师真实 Mobility，没有真实 Proc 或 Free Move。

## 安装与升级

1. 完全退出 WoW，把交付 ZIP 中 **CarGOUI 和 CarGOUI_Data 两个文件夹一起**放入 `_retail_/Interface/AddOns/`。这是同一个安装包，内部 Data 包会自动加载，不需要选择职业包。
2. 检查 `CarGOUI/CarGOUI.toc` 与 `CarGOUI_Data/CarGOUI_Data.toc` 都在上述目录下，没有多嵌套一层。
3. 从 alpha.8 升级时，退出游戏后删除旧 **AddOns/CarGOUI_Mage 程序目录**，再替换新包两个目录。**不要删除 WTF 中的 CarGOUI SavedVariables**。插件不会自动删除程序目录或用户存档。所有现有职业配置、Proc 样式、坐标及外壳设置保留。
4. 登录后 `/cui` 打开或关闭 Options；`/cargoui` 为别名。zhCN 客户端也默认英文。

从 GitHub 源码安装时：仓库主体作为 `CarGOUI`，另将其中 `Modules/CarGOUI_Data` 复制为 AddOns 下的同级 `CarGOUI_Data`。推荐直接使用交付安装 ZIP，避免遗漏内部模块。

## 配置范围

| 设置 | 归属 |
| --- | --- |
| Mobility 开关、字体、字号、描边、阴影、缩放、锚点、XY、偏好 | 当前 classToken，共用一套；Mage 三系及 Blink/Shimmer 共用 |
| Proc 字体、字号、描边、阴影、文字缩放 | 当前 classToken + specID，同专精所有区域共用 |
| Proc 区域锚点及 XY | 对应职业/专精下各区域分别保存 |
| Options 窗口位置、品牌动画开关 | 插件外壳独立保存 |

没有职业、专精、Profile 或手动 Theme 选择器。Appearance 的原选择字段现在只读显示自动配置上下文。Proc 区域菜单只选择预览/位置对象，不创建区域独立字体。

所有提醒名字和数字固定使用玩家的暴雪职业色，没有颜色编辑。Options 的阵营/专精主题与提醒颜色、字体、计时无关。

## 操作

Options 仍是左分类、右选项。Header、Body 背景、侧栏空白、边框与静态说明区域均可左键拖动整个窗口。按钮、滑块、输入框、下拉菜单及滚动条保留正常操作，不要求修饰键。松开、关闭或 Esc 结束拖动，位置保存与屏幕约束保留。General 与 Mobility 的开关/XY 都编辑当前职业的同一份 Mobility 配置。关闭 Mobility 也隐藏它的样例，不影响 Proc 样例。

Mobility / Proc → Appearance 提供 Font、Font Size、Outline、Shadow、Scale。菜单、勾选框和滑块立即生效；输入数字后按 Enter，没有 Apply。切换上下文、分类或关闭窗口会丢弃未提交输入。`Reset this context's style` 仅重置当前样式，不改坐标或其他范围。

`Reset Mobility offsets` 仅重置当前职业位移坐标；`Reset region offsets` 重置当前区域。`Reset class + Options` 需再次确认，只重置当前职业和外壳，保留其他职业和迁移备份。快捷 `reset` 命令仍会立即执行这个同样的范围。

字体内置 Friz Quadrata、Arial Narrow、Morpheus、Skurri（必要时提供 Client default）。工厂样式为 Friz Quadrata 24、OUTLINE、阴影开启、Scale 1。字号 8–72，缩放 0.5–3，新编辑 XY -10000–10000。缩放不会放大已有坐标。

Test Mode 使用外部游戏空间的固定 `8.0` 样例并标记 TEST。Proc **Preview only**，仍仅现有法师区域：奥法 Clearcasting 左右、火法 Hot Streak 左右、冰法 Fingers of Frost 左右和 Brain Freeze 上方。区域坐标独立，未实现真实 Buff 监控。没有新增未经核查的映射。

关闭窗口、Stop test、进战斗或切专精会停止样例并清理旧临时状态。Live 继续按真实 API 更新；正在测试同一区域时只暂时抑制对应 live 输出。提醒和引导不可拖动，没有 Unlock Mode。

## 分层自动主题

Header 只表达阵营：Alliance 蓝色、Horde 红色，中立/未知使用中性回退。同阵营切专精不改变 Header 主色或品牌强调色；原始彩色徽记/字标保持清晰。

Body 只读取职业＋专精，覆盖主体、侧栏及底部操作区。目标版本全部 13 职业、40 专精都有明确配色和图案；同职业专精使用不同成品主题。法师 Arcane 的深紫→奥术紫符文法阵、Fire 的暗红棕→琥珀橙火焰、Frost 的深蓝→冰青冰晶均保持 alpha.9 的原始定义。按钮、输入框、菜单使用同色系层次，普通正文保持清楚。[完整 Body 覆盖表、来源与逐项验收状态](docs/BODY_THEME_COVERAGE.md)。

未选专精使用本职业基础主题，身份暂不可用使用中性回退并在信息恢复事件后更新。打开窗口始终重新解析；隐藏时停止主题监听。关闭 Mobility、尚未学会位移、未加载业务适配器或关闭 Preview 均不影响主题。所有主题定义属于核心轻量 UI 数据，不为显示主题加载全职业业务或创建提醒框体。

图案位于 Body 右下内容背景，使用原创静态几何与原生 Line 的纯色线段绘制；不加载宣传图、不新增图片、粒子或旋转动画。共用线段池只绘制当前图案，身份变化或打开时更新；不承诺游戏纹理缓存立即卸载。Header 与 Body 配色映射独立，提醒职业色、字体、坐标、DurationTextBinding 和显隐不受影响。[分层主题与素材/API 来源](docs/THEMES.md)。

## 真实法师 Mobility

只监控实际学习、生效的 Blink 1953 / Shimmer 212653；有一次可用就隐藏，最后一次耗尽显示下一次恢复的真实倒计时，恢复一次立即不可见。计时使用正在进行的充能 DurationObject，不能从第二次使用重新起算。

可读状态直接判断；多充能数受限时，继续沿用原生冷却 DurationObject → 已核查曲线 → SetAlpha 路径。数字计时使用独立的充能恢复对象及 DurationTextBinding。原生结果不在 Lua 中比较、算术、拼接或反读。GCD、沉默、法力等其他原因不代替耗尽。容量不硬编码为两次。

`Native tracking` 表示原生管理可见性，Lua 不声称已知 Ready/Depleted。缺少接口或不符合 Blink/Shimmer 已核查元数据边界时，明确报告 Restricted/Unsupported 并安全隐藏。具体边界见[战斗 API 记录](docs/Mobility-Combat-API-Audit.md)。本轮 SpellState 的判断主体保持不变，仅调整内部命名空间前导代码，放入 Data 包的 Mage 私有适配器。

## 加载、诊断和限制

登录识别当前受支持职业后请求原生按需加载的 `CarGOUI_Data`。同一 Data TOC 列出的文件、静态定义会一起加载；职业子目录本身不具备独立按需加载能力。本轮只有 Mage 业务定义；将来添加职业文件后也不能声称其他职业代码仍完全未加载。

明确的职业适配器注册表选择当前职业，禁止多个职业文件依次覆盖核心方法。只有当前适配器运行当前专精/实际生效技能的路径，无无关技能查询、业务监听、提醒框体或计时绑定。重复注册被拒绝。残留旧 `CarGOUI_Mage` 若被加载，旧桥接写入隔离对象，不会覆盖新核心；升级仍应清理旧程序目录。

**架构取舍：统一两个顶级目录不满足此前严格逐职业文件/存档完全不载入的目标。** 核心账号级 `CarGOUIDB` 仍可能恢复所有已保存职业记录；仅当前范围被访问/初始化，并不等于其他记录未加载。配置不删除、不压缩、不强制 GC。实际开销须以客户端测量评估，不能用目录数或 ZIP 大小代替。

Mobility → `Copy diagnostics` / `Refresh snapshot` 现有入口记录四层边界：模块加载状态、活动条目实例、配置载入/访问情况、监听及活动/已分配绑定数量。额外按需读取游戏运行时内存 KB、累计 CPU ms；未开启 scriptProfile 时 CPU 标为不可用。没有新增按钮、后台采样、强制 GC、全库扫描或轮询。缓存框体和已加载代码不会假称卸载。详见[加载与实机测量](docs/LOAD_BOUNDARIES.md)。

## 迁移和验收

Schema 5 使用 `classes[classToken].mobility` 与 `classes[classToken].proc[specID]`。旧 Mage 配置仅进入 Mage；按实际生效技能和当前位置选择合并值，冲突原值及选择规则保存在 `migrations.scope5`。其他职业首次访问使用深复制的工厂默认值。迁移只补缺失/无效值，不在每次登录覆盖新配置。[迁移规则与验收清单](docs/CONFIG_SCOPES.md)。

离线测试保留战斗秘密值与战斗标志分别模拟的回归，并验证范围隔离、延迟初始化、加载/订阅/绑定有界、主题和草稿行为。交付报告记录**最终 ZIP 解包后的测试**及 SHA256。

**开发环境没有真实 WoW 客户端。** 用户已确认升级前 Blink/Shimmer 及 alpha.9 法师 Header/Body 正常；alpha.10 所有新增主题的实机视觉、各 UI 缩放、安装后战斗回归与 CPU/内存实测仍待验收。离线映射或模拟图案检查不作为实机验收。其他职业的 Body 支持不代表其真实 Mobility 已支持。

## 源码结构

`Core/`：初始化、事件、配置校验迁移、按需加载、诊断；`Config/`：工厂默认、英文文案、命令；`Database/`：通用样式上下文与主题映射；`UI/`：共用提醒、Preview、Options、品牌/主题；`Modules/Mobility/Runtime.lua`：当前活动技能事件引擎；`Modules/CarGOUI_Data/`：统一 LoD TOC、职业注册及 `Classes/Mage/` 私有适配器；`tests/`：Lua 5.1 离线测试与静态检查。

运行 `python tests/run_tests.py`、`python tests/check_mobility_static.py`、`python tests/check_styles_theme_static.py`。需要已有 Lua 5.1/LuaJIT 或 `lupa.lua51`，运行器不自动安装依赖。

两目录升级清理、全面板拖动接口核查见 [UPGRADE_ALPHA9.md](docs/UPGRADE_ALPHA9.md)；本轮新增主题验收见 [BODY_THEME_COVERAGE.md](docs/BODY_THEME_COVERAGE.md)。从 alpha.9 更新只需替换两个程序目录，继续保留 WTF / SavedVariables，无新增配置迁移。
