# CarGOUI Alpha 0.1

轻量、独立的 WoW Retail AddOn。当前版本 `0.1.0-alpha.2` 包含 Phase 1 基础框架和独立图形设置窗口，目标客户端为 Retail 12.1.0（Interface `120100`）。无需其他插件或外部媒体库。

输入 `/cargoui` 打开或关闭设置窗口。位置、字体、字号、描边、缩放、阴影和显示开关都可在窗口内完成。`/cargoui help` 显示可选命令帮助。

## 安装

1. 完全退出 WoW。
2. 将安装包内的整个 `CarGOUI` 文件夹复制到正式服目录 `_retail_\Interface\AddOns\`。
3. 确认最终路径为 `_retail_\Interface\AddOns\CarGOUI\CarGOUI.toc`，没有额外的同名目录嵌套。
4. 启动游戏，在角色选择界面的插件列表中启用 CarGOUI。

也可下载本仓库的 ZIP，将解压后的仓库目录重命名为 `CarGOUI` 后安装。升级时替换插件文件即可；账号设置保存在 WTF 目录中。

首次登录后，默认在屏幕中央显示 `CarGOUI` 文字：Friz Quadrata、24 号、普通描边、缩放 1、阴影开启。当前是基础显示框体，尚未加入职业技能或 Buff 逻辑。

## 图形设置窗口

窗口采用左侧分类、右侧选项布局。简体中文客户端使用中文标签，其余客户端使用英文标签。再次输入 `/cargoui`、按 Esc 或点击关闭按钮均可关闭窗口。

| 分类 | 可操作设置 |
| --- | --- |
| 常规 / General | 显示开关；X/Y 输入框和应用按钮；恢复居中；缩放滑块与精确数值输入 |
| 字体与外观 / Font & appearance | 字体下拉菜单；字号滑块与精确数值输入；描边下拉菜单；阴影复选框 |
| 预览 / Preview | 使用当前字体、字号、描边、阴影和缩放的静态文字样例 |

字体菜单提供游戏内置的 Friz Quadrata、Arial Narrow、Morpheus、Skurri。若客户端标准字体与这些字体不同，也会提供 `Client default` 选项。标签自身使用客户端界面字体，避免中文标签依赖 Friz 字体。

可用范围：

- X/Y：-10000 至 10000。正 X 向右、正 Y 向上，锚点固定为 CENTER。偏移使用 UIParent 界面坐标单位，不是固定物理像素。
- 字号：8 至 72。滑块以 1 为步长；输入框允许精确数值。
- 缩放：0.5 至 3。滑块以 0.05 为步长；输入框允许精确数值。缩放不改变设定的视觉偏移。
- 描边：无、普通、加粗。

勾选框、下拉菜单和滑块的修改立即生效。输入数值后按 Enter 或点击对应的应用按钮；X/Y 会作为一组完整校验后一起应用。无效输入会在窗口底部显示错误，并保留原配置。切换分类或关闭窗口会丢弃尚未应用的输入。

底部的“重置全部设置”按钮需要再次点击“确认重置”才会恢复默认值。点击关闭或切换分类会取消这次重置确认。

预览只显示静态 `CarGOUI` 文字，不模拟技能、倒计时或 Buff。过大文字会缩小以适应预览区，实际显示框体仍使用配置值。关闭设置窗口后，面板预览隐藏；实际显示框体是否显示由常规页的显示开关决定。

Mobility、Proc、主题、导入/导出分类均标记为“未实现”并禁用。没有提醒框体拖动、Unlock Mode 或布局编辑器。

## 游戏内验收

建议先仅启用 CarGOUI，并使用 `/console scriptErrors 1` 开启错误弹窗。

1. `/reload` 后确认屏幕中央有占位文字；此时设置窗口不应自行出现。
2. 输入 `/cargoui`。应打开独立窗口，左侧可选择常规、字体与外观、预览。未实现分类应灰显且不能打开。
3. 在常规页输入 X=100、Y=-80，点击应用。再把缩放设为 1.2。关闭窗口，观察实际文字的位置和大小。
4. 重新打开窗口，在字体页依次选择字体，把字号设为 30，选择加粗描边并关闭阴影。前往预览页确认文字变化；可切回字体页继续调整。
5. 再次输入 `/cargoui` 应关闭窗口。在打开的窗口内按 Esc，或先点击输入框再按 Esc，也应关闭窗口并释放输入焦点。
6. 重新打开，输入无效数值或超过范围的数值再点击应用。应出现窗口内错误提示，已保存值保持不变。
7. 在 X/Y 输入框输入一个值但不应用，关闭窗口再打开。输入框应恢复已保存的数值。
8. 在常规页关闭显示开关，关闭窗口并 `/reload`。文字应保持隐藏；重新打开窗口可恢复显示。
9. `/reload` 后打开窗口，检查字体、字号、描边、位置、缩放和阴影保留。点击重置全部设置，确认第一次点击不会重置，第二次确认后恢复默认值。
10. 反复打开/关闭窗口，切换分类及打开下拉菜单。确认没有 Lua 错误、残留下拉菜单或不能释放的输入焦点。

可用 `/dump select(4, GetBuildInfo())` 检查客户端 Interface。此版本面向 `120100`。出现错误时，请保留完整错误文本、操作步骤和客户端版本。

## 文件结构

```text
CarGOUI/
├── CarGOUI.toc             # 元数据与 9 个 Lua 文件的加载顺序
├── Core/
│   ├── Addon.lua           # 私有命名空间、版本与聊天输出
│   ├── Events.lua          # 事件订阅与分发
│   ├── Database.lua        # SavedVariables、共享校验与设置更新接口
│   └── Initialize.lua      # ADDON_LOADED / PLAYER_LOGIN 初始化
├── Config/
│   ├── Defaults.lua        # 默认值、字体列表与数值范围
│   ├── Locale.lua          # 设置窗口的中文与英文文案
│   └── Commands.lua        # 默认打开窗口及可选兼容命令
├── UI/
│   ├── Display.lua         # 显示框体与共用字体渲染
│   └── Options.lua         # 延迟创建的独立图形设置窗口
├── Modules/Mobility/       # 预留
├── Modules/Proc/           # 预留
├── Database/               # 预留
├── Media/Fonts/            # 预留；使用客户端字体
└── tests/                  # 离线 Lua 5.1 测试及 Python 运行器
```

预留目录中的 `.gitkeep`、README 和测试脚本不会被 WoW 加载。

## 配置与性能

配置仍只有账号级 `CarGOUIDB`，各角色共享。没有新增第二套配置、布局或预览 SavedVariables。

```lua
CarGOUIDB = {
    schemaVersion = 1,
    enabled = true,
    position = { x = 0, y = 0 },
    font = { face = "Fonts\\FRIZQT__.ttf", size = 24, outline = "OUTLINE" },
    scale = 1,
    shadow = { enabled = true },
}
```

`InitializeDatabase()` 负责首次加载、补齐缺失字段、修复异常值，并保留未知的已有字段。`UpdateSettings(patch)` 先校验完整修改再写入，成功后统一调用 `ApplySettings()` 和可见面板刷新；图形控件与兼容命令共用此接口。显式重置会重建默认配置。

WoW 在 `/reload`、登出或正常退出时保存设置。磁盘位置通常是 `_retail_\WTF\Account\<账号目录>\SavedVariables\CarGOUI.lua`。

设置窗口在第一次打开时创建，之后复用全部框体与控件。关闭时清理输入焦点、关闭下拉菜单并隐藏预览。隐藏窗口的刷新接口直接返回；只有预览分类打开时才刷新静态样例。面板没有常驻事件订阅、`OnUpdate`、轮询计时器或每帧扫描。

窗口内尚未确认的数字只存在于输入框和临时脏状态标记中，不会保存到数据库。面板首次打开及再次显示时会根据当前屏幕尺寸适当缩小，以适应小尺寸界面。

## 可选兼容命令

日常设置可全部通过窗口完成。以下命令保留用于调试或习惯命令操作的用户：

| 命令 | 功能 |
| --- | --- |
| `/cargoui` | 打开或关闭设置窗口 |
| `/cargoui help` | 显示命令帮助 |
| `/cargoui status` | 输出当前配置 |
| `/cargoui show` / `hide` | 显示或隐藏占位文字 |
| `/cargoui position 100 -80` | 修改偏移 |
| `/cargoui font friz` | 选择字体；也支持 arial、morpheus、skurri、default |
| `/cargoui fontsize 30` | 修改字号 |
| `/cargoui outline none` | 修改描边；也支持 outline、thickoutline |
| `/cargoui scale 1.2` | 修改缩放 |
| `/cargoui shadow on` / `off` | 开启或关闭阴影 |
| `/cargoui reset` | 立即恢复默认设置 |

## 验证范围

22 项 Lua 5.1 离线测试全部通过，覆盖原有加载生命周期、SavedVariables、命令与事件分发，以及窗口延迟创建、反复复用、全部控件的设置更新、原子校验、待确认输入、关闭清理、预览停止、滑块边界、字体切换、配置保留和小尺寸界面下的控件边界。

测试使用 WoW API 模拟对象。**尚未在真实 Retail 12.1 客户端中实测，仍需按上面的步骤检查实际渲染、点击、焦点和模板兼容性。**

开发者可以从插件目录执行 `lua5.1 tests/smoke.lua .`，或运行 `python tests/run_tests.py`。Python 运行器使用本机已有的 Lua 5.1/LuaJIT 或 `lupa.lua51`，不会自动安装依赖。普通玩家不需要这些测试依赖。

## API 核查来源

- [Blizzard 12.1.0 AddOn API 源码镜像](https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)
- [输入框模板](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml)
- [原生 Slider API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua)
- [游戏字体定义](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Fonts_Shared/Shared/GameFonts.xml)
- [Esc 窗口关闭机制](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua)
