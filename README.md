# CarGOUI Alpha 0.1

独立、轻量的 WoW Retail AddOn，当前版本 `0.1.0-alpha.3`，目标为 Retail 12.1.0（Interface `120100`）。此阶段包含独立 Options、外部模拟 Test Mode 与品牌标题；真实 Mobility / Proc 检测尚未实现。

`/cui` 是主命令，打开或关闭 Options；`/cargoui` 保留为兼容别名。当前阶段统一使用英文界面，包括 zhCN 客户端。中文文案保留但未启用，没有语言切换选项。

## 安装

1. 完全退出 WoW，将安装包中的 `CarGOUI` 文件夹放入 `_retail_\Interface\AddOns\`。
2. 确认路径为 `_retail_\Interface\AddOns\CarGOUI\CarGOUI.toc`，不要多嵌套一层目录。
3. 启动游戏，在插件列表启用 CarGOUI，登录后输入 `/cui`。

从 GitHub 下载分支 ZIP 时，将解压后的仓库文件夹重命名为 `CarGOUI`。升级时替换插件文件；原设置会保留并补齐新字段。登录时不再显示旧的静态 CarGOUI 占位文字，需主动启动 Test Mode 才会显示模拟提醒。

## Options 操作

窗口保留左侧分类、右侧选项布局。只有顶部品牌标题区域可以拖动；窗口始终限制在屏幕内，位置单独保存。输入框、滑块、下拉菜单和按钮不会触发窗口拖动。General 中的 `Center window` 可将设置窗口恢复居中。

| 分类 | 可用功能 |
| --- | --- |
| General | Show reminder samples、全局 X/Y、缩放、Animated title、Center window |
| Font & appearance | 字体、字号、描边、阴影 |
| Test Mode | 选择当前专精的提醒区域、Test selected、Test current spec、Stop test、所选区域独立 X/Y |

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
2. Mobility 样例使用固定的 `No Shimmer` 和 `8.0`。Proc 主体只显示固定倒计时数字，不装饰成带图标、技能名称的大框。
3. 测试期间显示淡化的暴雪形状、区域标记等引导，帮助识别正在调整的 Proc 位置。Proc 引导固定在原版区域，偏移只移动计时数字。这些引导仅用于测试，不属于最终实时计时器设计。
4. 修改全局 X/Y、字号、缩放、字体、描边、阴影或所选区域 X/Y，会立即作用于正在显示的外部样例。可切到其他设置页继续调整，不会停止测试。
5. `Stop test` 或关闭 Options 会移除所有样例及引导。重新打开窗口不会自动恢复测试。General 的 `Show reminder samples` 可隐藏样例，测试模式选择仍保留到窗口关闭。

当前只定义法师三个专精的模拟条目：

| 专精 | 已定义模拟条目 |
| --- | --- |
| Arcane | Shimmer；Clearcasting 左、右区域 |
| Fire | Shimmer；Hot Streak 左、右区域 |
| Frost | Shimmer；Fingers of Frost 左、右区域；Brain Freeze 上方区域 |

同一效果的多个视觉区域有独立条目与独立偏移。Proc 默认定位对应原版暴雪指示器区域，绝非全部堆在屏幕中央；其他插件若移动或缩放暴雪指示器，需要通过区域偏移另行校准。区域几何和客户端数据来源见 `Database/PreviewEntries.lua` 与 [实现说明](docs/IMPLEMENTATION.md)。更换专精时更新可用目录；没有定义条目的职业/专精会明确提示并禁用测试操作。

这些条目是固定模拟样例，不判断天赋、技能是否已学、真实 Buff、真实充能或冷却。模拟状态只保存在内存，和未来的真实提醒状态分离。

## 标题与品牌素材

Options 标题使用蓝金色幻想风格边饰、货箱与移动意象徽记、原生字体字标。General 的 `Animated title` 默认开启，使用 WoW 原生 AnimationGroup 让柔和蓝光呼吸变化；关闭开关保留相同静态标题，关闭窗口停止动画。

`Media/Branding/` 保存游戏用 TGA、可编辑 SVG 和生成脚本，便于将来制作 Curse 宣传图。资产用途、来源和校验方式见 [品牌素材说明](Media/Branding/README.md)。此阶段没有制作完整的 Curse 宣传页面。

## 实现状态与性能

| 状态 | 范围 |
| --- | --- |
| 已实现 | 初始化、事件管理、共享 SavedVariables/校验、独立英文 Options、Enter 提交、窗口位置保存、品牌标题与动画开关 |
| 仅模拟 | 当前法师目录的 Mobility / Proc 外部提醒、区域定位、样例数字及测试引导 |
| 尚未实现 | 真实技能/充能/冷却/Buff 检测、其他职业目录、其余效果、职业主题、导入/导出 |

Mobility、Proc、Themes、Import / Export 的运行时设置分类标注 `Not implemented` 并禁用；现有模拟配置集中在 Test Mode。

配置仍只有账号级 `CarGOUIDB`：`position` 是全局提醒偏移，`reminders[id].position` 是各区域偏移，`options.position` 是设置窗口位置，`options.animatedTitle` 控制标题动画。所有持久化修改共用 `UpdateSettings(patch)` 校验、保存和显示更新流程，没有第二套配置系统。旧设置升级为 schema 2，保留既有显示设置及未知字段。

Options 首次打开才创建，后续复用。模拟框体按需创建并复用，关闭后停止预览、动画和临时事件订阅。没有常驻 OnUpdate、每帧扫描或轮询计时器；只在用户操作、窗口显示及专精变化事件时刷新。WoW 在 `/reload`、登出或正常退出时将 SavedVariables 写入 WTF。

## 游戏内验收

建议先只启用 CarGOUI，并使用 `/console scriptErrors 1` 开启错误弹窗。

1. 登录后用 `/cui` 开关窗口，再验证 `/cargoui` 相同行为。`/cui help` 显示帮助；zhCN 客户端的界面和提示仍为英文。
2. 拖动标题到屏幕侧边，关闭重开、`/reload` 后确认窗口位置保留。尝试操作各输入框、滑块、菜单，窗口不应跟着拖动。
3. 全局 X 输入 100、Y 输入 -80，在任一框按 Enter。确认两值同时保存。输入一个无效轴再按 Enter，确认两轴均未改变。
4. Scale 和 Font size 分别测试滑块与数字 Enter。输入数值但不按 Enter，关闭重开，应恢复保存值。
5. 在法师当前专精选 Test Mode，分别启动单条与全部样例，将窗口移开查看外部提醒。调整外观、全局偏移及区域偏移，检查对应变化。
6. 检查多区域 Proc 的位置和独立条目，确认数字居于目标指示形状的视觉中心；检查实际 UI 缩放与分辨率下的字体和形状。
7. 切换专精，确认目录与样例更新。停止测试、Esc、Close 或 `/cui` 关闭后，应无样例、引导或残留菜单；重新打开不自动测试。
8. 开关 Animated title：关闭时保留静态标题，开启时柔和呼吸，关闭窗口停止动画。
9. 测试重置确认、隐藏样例、配置重载保留；反复开关窗口应无 Lua 错误。

31 项 Lua 5.1 离线测试通过，覆盖命令别名、Enter 提交与无效输入、窗口拖动保存、动画开关、外部模拟生命周期、专精切换、独立区域偏移和固定 Proc 引导；测试还拒绝真实 Buff/冷却读取、轮询计时器和 OnUpdate。

**离线测试使用 WoW API 模拟对象，不能替代真实 Retail 12.1 客户端验收。尚未进行游戏内实测。** 开发者可运行 `python tests/run_tests.py` 或 `lua5.1 tests/smoke.lua .`。运行器使用已有 Lua 5.1/LuaJIT 或 `lupa.lua51`，不会自动安装依赖。

## 文件与兼容命令

核心仍在 `Core/`、默认值/英文文案/命令在 `Config/`。`UI/Options.lua` 管理交互，`UI/Display.lua` 提供共用提醒渲染，`UI/Preview.lua` 管理模拟生命周期，`UI/Branding.lua` 管理标题，`Database/PreviewEntries.lua` 保存模拟目录；TOC 按依赖顺序加载。详见 [实现说明](docs/IMPLEMENTATION.md)。

命令主入口均为 `/cui`，`/cargoui` 完整兼容：`help`、`status`、`show`、`hide`、`position <x> <y>`、`font <friz|arial|morpheus|skurri|default>`、`fontsize <8-72>`、`outline <none|outline|thickoutline>`、`scale <0.5-3>`、`shadow <on|off>`、`reset`。日常操作可全部在窗口完成，`reset` 命令会立即重置。
