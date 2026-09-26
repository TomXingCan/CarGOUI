# CarGOUI Alpha 0.1

当前版本 **0.1.0-alpha.8**，目标 WoW Retail 12.1.0（Interface 120100）。本轮纠正配置范围、自动阵营配色，并准备职业按需加载。保留用户已实测通过的 Blink / Shimmer 战斗路径；没有开始其他职业真实 Mobility、真实 Proc 或 Free Move。

## 安装与升级

1. 完全退出 WoW，把交付 ZIP 中 **CarGOUI 和 CarGOUI_Mage 两个文件夹一起**放入 `_retail_/Interface/AddOns/`。这是同一个安装包，内部法师模块会自动加载，不需要选择职业包。
2. 检查 `CarGOUI/CarGOUI.toc` 与 `CarGOUI_Mage/CarGOUI_Mage.toc` 都在上述目录下，没有多嵌套一层。
3. 替换旧插件文件，**不要删除 WTF 中的 CarGOUI SavedVariables**。旧坐标、有效外观、窗口位置和标题动画设置会迁移/保留。
4. 登录后 `/cui` 打开或关闭 Options；`/cargoui` 为别名。zhCN 客户端也默认英文。

从 GitHub 源码安装时：仓库主体作为 `CarGOUI`，另将其中 `Modules/CarGOUI_Mage` 复制为 AddOns 下的同级 `CarGOUI_Mage`。推荐直接使用交付安装 ZIP，避免遗漏内部模块。

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

Options 仍是左分类、右选项，顶部标题栏可以拖动。General 与 Mobility 的开关/XY 都编辑当前职业的同一份 Mobility 配置。关闭 Mobility 也隐藏它的样例，不影响 Proc 样例。

Mobility / Proc → Appearance 提供 Font、Font Size、Outline、Shadow、Scale。菜单、勾选框和滑块立即生效；输入数字后按 Enter，没有 Apply。切换上下文、分类或关闭窗口会丢弃未提交输入。`Reset this context's style` 仅重置当前样式，不改坐标或其他范围。

`Reset Mobility offsets` 仅重置当前职业位移坐标；`Reset region offsets` 重置当前区域。`Reset class + Options` 需再次确认，只重置当前职业和外壳，保留其他职业和迁移备份。快捷 `reset` 命令仍会立即执行这个同样的范围。

字体内置 Friz Quadrata、Arial Narrow、Morpheus、Skurri（必要时提供 Client default）。工厂样式为 Friz Quadrata 24、OUTLINE、阴影开启、Scale 1。字号 8–72，缩放 0.5–3，新编辑 XY -10000–10000。缩放不会放大已有坐标。

Test Mode 使用外部游戏空间的固定 `8.0` 样例并标记 TEST。Proc **Preview only**，仍仅现有法师区域：奥法 Clearcasting 左右、火法 Hot Streak 左右、冰法 Fingers of Frost 左右和 Brain Freeze 上方。区域坐标独立，未实现真实 Buff 监控。没有新增未经核查的映射。

关闭窗口、Stop test、进战斗或切专精会停止样例并清理旧临时状态。Live 继续按真实 API 更新；正在测试同一区域时只暂时抑制对应 live 输出。提醒和引导不可拖动，没有 Unlock Mode。

## 自动主题

Alliance 使用蓝色阵营端，Horde 使用红色阵营端，组合当前专精风格。奥法分别为 **蓝→奥术紫 / 红→奥术紫**；火法第二端使用琥珀/焦橙、冰法使用冰青/钢青，这是本轮设计提案。中性或未知身份自动回退。

主题仅影响 Options 标题背景、分类选中背景、细边框/线和品牌强调色。深色正文与输入框保持可读。使用已有原生静态渐变和少量复用纹理，不增加图片/逐帧变色，不染整张 Logo。动画开关及进战斗停止规则保留。[主题映射与 API 核查](docs/THEMES.md)。

## 真实法师 Mobility

只监控实际学习、生效的 Blink 1953 / Shimmer 212653；有一次可用就隐藏，最后一次耗尽显示下一次恢复的真实倒计时，恢复一次立即不可见。计时使用正在进行的充能 DurationObject，不能从第二次使用重新起算。

可读状态直接判断；多充能数受限时，继续沿用原生冷却 DurationObject → 已核查曲线 → SetAlpha 路径。数字计时使用独立的充能恢复对象及 DurationTextBinding。原生结果不在 Lua 中比较、算术、拼接或反读。GCD、沉默、法力等其他原因不代替耗尽。容量不硬编码为两次。

`Native tracking` 表示原生管理可见性，Lua 不声称已知 Ready/Depleted。缺少接口或不符合 Blink/Shimmer 已核查元数据边界时，明确报告 Restricted/Unsupported 并安全隐藏。具体边界见[战斗 API 记录](docs/Mobility-Combat-API-Audit.md)。本轮该 SpellState 源码字节保持不变，仅移入内部 Mage 模块。

## 加载、诊断和限制

登录识别当前职业后自动请求对应内部模块。本轮只有 Mage：其他职业不请求 Mage 业务文件、不创建 Mage 活动条目、不注册 Mobility 运行监听或查询冷却。Mage 内只有当前专精的条目被实例化；三个专精的工厂函数定义会随 Mage 文件加载，不宣称代码卸载。

**尚未达到其他职业配置严格未加载的要求**：核心账号级 `CarGOUIDB` 仍载入所有已保存职业表。普通访问和缺省初始化只针对当前范围，但这不等于存储隔离。后续阶段在宣称严格隔离前须迁移到模块自有 SavedVariables，不能直接复制 Mage 适配器后宣称完成。

Mobility → `Copy diagnostics` / `Refresh snapshot` 现有入口记录四层边界：模块加载状态、活动条目实例、配置载入/访问情况、监听及活动/已分配绑定数量。额外按需读取游戏运行时内存 KB、累计 CPU ms；未开启 scriptProfile 时 CPU 标为不可用。没有新增按钮、后台采样、强制 GC、全库扫描或轮询。缓存框体和已加载代码不会假称卸载。详见[加载与实机测量](docs/LOAD_BOUNDARIES.md)。

## 迁移和验收

Schema 5 使用 `classes[classToken].mobility` 与 `classes[classToken].proc[specID]`。旧 Mage 配置仅进入 Mage；按实际生效技能和当前位置选择合并值，冲突原值及选择规则保存在 `migrations.scope5`。其他职业首次访问使用深复制的工厂默认值。迁移只补缺失/无效值，不在每次登录覆盖新配置。[迁移规则与验收清单](docs/CONFIG_SCOPES.md)。

离线测试保留战斗秘密值与战斗标志分别模拟的回归，并验证范围隔离、延迟初始化、加载/订阅/绑定有界、主题和草稿行为。交付报告记录**最终 ZIP 解包后的测试**及 SHA256。

**开发环境没有真实 WoW 客户端。** 用户已确认升级前 Blink/Shimmer 正常；alpha.8 新包的实机迁移、渲染、安装后战斗回归、CPU/内存实测均待验收。离线 mock 值不作为真实客户端测量。Phase B 全职业 Mobility 尚未开始。

## 源码结构

`Core/`：初始化、事件、配置校验迁移、按需加载、诊断；`Config/`：工厂默认、英文文案、命令；`Database/`：通用样式上下文与主题映射；`UI/`：共用提醒、Preview、Options、品牌/主题；`Modules/Mobility/Runtime.lua`：当前活动技能事件引擎；`Modules/CarGOUI_Mage/`：内部 LoD TOC、桥接、Mage 数据及未改动的 SpellState；`tests/`：Lua 5.1 离线测试与静态检查。

运行 `python tests/run_tests.py`、`python tests/check_mobility_static.py`、`python tests/check_styles_theme_static.py`。需要已有 Lua 5.1/LuaJIT 或 `lupa.lua51`，运行器不自动安装依赖。
