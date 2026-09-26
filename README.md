# CarGOUI Alpha 0.1 — Phase 1

已实现可独立安装的 AddOn 基础框架。目标客户端为 WoW Retail 12.1.0，TOC Interface 为 `120100`。无需 Ace3、LibSharedMedia 或其他插件。

默认在屏幕中央显示 `CarGOUI` 文本：Friz Quadrata、24 号、普通描边、阴影开启。通过命令调整位置和字体，立即生效。框体不接受鼠标操作，不支持拖动。

## 文件结构

```text
CarGOUI/
├── CarGOUI.toc             # 插件元数据、SavedVariables 和加载顺序
├── Core/
│   ├── Addon.lua           # 私有命名空间、版本和聊天输出
│   ├── Events.lua          # 单一事件框体、多订阅者事件分发
│   ├── Database.lua        # 默认值合并、设置校验和重置
│   └── Initialize.lua      # ADDON_LOADED / PLAYER_LOGIN 生命周期
├── Config/
│   ├── Defaults.lua        # 默认设置和允许的数值范围
│   └── Commands.lua        # /cargoui 设置命令
├── UI/
│   └── Display.lua         # CENTER 文本框体、位置和字体应用
├── Modules/
│   ├── Mobility/           # 预留目录
│   └── Proc/               # 预留目录
├── Database/               # 预留目录
├── Media/
│   └── Fonts/              # 预留目录；使用游戏自带字体
├── tests/
│   ├── smoke.lua           # 10 项离线测试
│   └── run_tests.py        # 可选本地测试运行器
└── README.md
```

预留目录内的 `.gitkeep` 用于保留目录结构，不会被 WoW 加载。TOC 只加载列出的 7 个运行时 Lua 文件；README 和 tests 也不会被加载。

## 安装

1. 完全退出 WoW。
2. 解压交付的 ZIP，将其中的整个 `CarGOUI` 文件夹复制到正式服安装目录的 `_retail_\Interface\AddOns\` 下。
3. 确认最终路径是 `_retail_\Interface\AddOns\CarGOUI\CarGOUI.toc`，不要多套一层同名文件夹，也不要放进 Classic 目录。
4. 启动 WoW，在角色选择界面的插件列表中启用 `CarGOUI`，然后进入游戏。

登录后应看到一条 CarGOUI 加载提示，以及屏幕中央的 `CarGOUI` 文本。

## 命令

| 命令 | 效果 |
| --- | --- |
| `/cargoui` 或 `/cargoui help` | 显示命令帮助 |
| `/cargoui status` | 显示当前设置 |
| `/cargoui position 100 -80` | 相对屏幕中央向右 100、向下 80 |
| `/cargoui fontsize 30` | 设置字号，允许 8–72 |
| `/cargoui outline none` | 关闭描边 |
| `/cargoui outline outline` | 普通描边 |
| `/cargoui outline thickoutline` | 加粗描边 |
| `/cargoui scale 1.2` | 设置缩放，允许 0.5–3 |
| `/cargoui shadow off` 或 `/cargoui shadow on` | 关闭或开启阴影 |
| `/cargoui hide` 或 `/cargoui show` | 隐藏或显示文本 |
| `/cargoui reset` | 将本插件全部设置重置为默认值，并显示文本 |

X/Y 范围为 -10000–10000，单位为 UIParent 的界面坐标单位，并非固定物理像素。X 正数向右，Y 正数向上。缩放不会改变设置的视觉偏移；如果将框体移出屏幕，可用 `/cargoui reset` 恢复。

本阶段使用命令设置，没有图形选项面板。显示的是固定占位文本，没有倒计时或模拟战斗事件。

## 游戏内验收

建议先仅启用 CarGOUI，以便定位本插件的错误。逐条执行命令，不要把下面多行一次性粘贴到聊天框。

1. 输入 `/console scriptErrors 1`，再输入 `/reload`。应出现加载提示和居中文本，且没有 Lua 错误弹窗。
2. 输入 `/dump select(4, GetBuildInfo())` 检查当前客户端 Interface。此版本面向 `120100`；若结果不同，应针对实际客户端复核兼容性。
3. 输入 `/cargoui` 和 `/cargoui status`，确认帮助和初始设置正常。
4. 输入 `/cargoui position 100 -80`，确认文本向右下方移动；输入 `/cargoui fontsize 30`，确认字号变大。
5. 依次输入 `/cargoui outline none`、`/cargoui outline outline`、`/cargoui outline thickoutline`，确认描边变化。
6. 输入 `/cargoui scale 1.2` 和 `/cargoui shadow off`，确认缩放和阴影变化，位置仍保持相同偏移。
7. 输入 `/reload`，再输入 `/cargoui status`。应保留 X=100、Y=-80、字号 30、加粗描边、缩放 1.2、阴影关闭。
8. 输入 `/cargoui hide`，再 `/reload`；文本应保持隐藏。输入 `/cargoui show` 后应恢复显示。
9. 输入 `/cargoui fontsize nope`、`/cargoui position 10` 或 `/cargoui outline bogus`。应仅显示参数提示，不报错也不改变设置。
10. 输入 `/cargoui reset`。文本应恢复居中、24 号、普通描边、缩放 1、阴影开启。

可用 `/dump CarGOUIDB` 查看内存中的配置。完成测试后，如需关闭错误弹窗，可输入 `/console scriptErrors 0`。

如出现错误，请保留完整错误文本、触发命令、客户端版本及 `/cargoui status` 的输出，以便复现。

## SavedVariables 与生命周期

配置为账号级共享，变量名为 `CarGOUIDB`。WoW 会在 `/reload`、登出或正常退出时保存；不要在游戏运行期间手动编辑磁盘上的 SavedVariables。

正常保存位置为 `_retail_\WTF\Account\<账号目录>\SavedVariables\CarGOUI.lua`。

```lua
CarGOUIDB = {
    schemaVersion = 1,
    enabled = true,
    position = { x = 0, y = 0 },
    font = {
        face = "Fonts\\FRIZQT__.ttf",
        size = 24,
        outline = "OUTLINE",
    },
    scale = 1,
    shadow = { enabled = true },
}
```

仅在本插件的 `ADDON_LOADED` 事件中初始化配置，并在 `PLAYER_LOGIN` 后创建显示框体。若加载时已经登录，则直接创建框体。缺失字段会补默认值；已知字段的类型、范围或描边值无效时会恢复为默认值；其他未知字段会保留。`enabled` 只控制占位文本显示，不会卸载插件。

Lua 文件通过 WoW 提供的 `local addonName, addon = ...` 共享私有命名空间。事件接口为 `addon:RegisterEvent(event, callback)` 和 `addon:UnregisterEvent(event, callback)`；回调参数为 `(addon, event, ...)`。同一回调不会重复订阅，订阅变化从下次事件开始生效；回调错误会交给 WoW 错误处理器，其他订阅者继续执行。这里订阅的是游戏事件。

运行时代码没有 `OnUpdate`、轮询计时器、职业技能逻辑、Mobility/Proc 数据库或外部依赖。字体来自游戏客户端；若 Friz 无法加载，会尝试客户端标准字体。

## 已完成的验证

已使用 Lua 5.1 执行 10 项离线测试，全部通过：

- TOC 元数据、文件存在性和实际加载顺序。
- 首次加载、无关插件事件过滤及重复事件处理。
- 已保存设置在模拟重载后保留。
- 已登录状态下的插件加载。
- 异常 SavedVariables、NaN 和无限大数值的恢复。
- 命令对位置、字体、缩放、阴影和重置的应用，以及无效参数拒绝。
- 隐藏状态在模拟重载后保留。
- 事件订阅快照与重复订阅处理。
- 事件参数中 nil 的保留。
- 单个监听器出错后其他监听器继续执行。

这些测试使用 WoW API 模拟对象，验证 Lua 语法及框架行为。尚未在真实 WoW Retail 客户端中运行，不能代替上面的游戏内验收，尤其是字体渲染、界面缩放和客户端加载行为。

开发者可在已安装 Lua 5.1/LuaJIT 的环境中，从插件目录执行：

```text
lua5.1 tests/smoke.lua .
```

也可运行 `python tests/run_tests.py`，它会查找 Lua 5.1/LuaJIT，或使用当前 Python 环境中的 `lupa.lua51`。测试运行器不会自动安装依赖。普通玩家不需要 Python 或 Lua 运行时，WoW 自身负责执行插件。

## API 核查来源

- [Blizzard 12.1.0 AddOn API 源码镜像](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)：`ADDON_LOADED` 事件。
- [Blizzard 命令注册源码镜像](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua)：SlashCmdList 命令注册方式。
- [Blizzard 字体定义源码镜像](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Fonts_Shared/Mainline/GameFonts.xml)：Friz Quadrata 游戏字体路径。
