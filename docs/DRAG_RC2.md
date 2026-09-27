# RC2：Options 起拖与结束生命周期修复

基线为 RC1 提交 `9c29f62684c54adc40618f4a215bab28a9d84edc`，原安装 ZIP SHA256 为 `88e74d54a122d703dc57d5ed5fc3048c5d7b68245612a606742675aafb6f87a1`。本轮版本为 **1.0.0-rc.2**，仅作为修复候选，没有合并 main、创建正式 Release 或上传 CurseForge。

## 交接材料与核对

用户提供 `CarGOUI-RC1-Drag-Codex-Handoff.zip`，SHA256：`f923a734d6686b9cff5d536893803c5f3f8779762ff078397e0409a42fc669b7`。压缩包 CRC 检查通过，内含补丁、说明、独立回归用例和外部测试记录。补丁在当前 RC1 工作树上通过 `git apply --check`；原有 204 组测试保留，交接的 11 组拖动用例作为追加回归合入。

附件中的 Linux / Lua 5.4 兼容测试器没有被用于本轮结果，也没有被放进安装包。其测试报告是交接证据；本轮另用项目已有的实际 Lua 5.1 环境重测。附件另行列出的 dragfix ZIP 哈希不代表本轮安装包；请使用本次交付 ZIP 旁的 SHA256。

## 问题与修复

交接记录描述的是偶发起拖瞬间跳位，之后在按住鼠标时出现远距离牵引。按住时继续跟随鼠标本身是正常拖动，不能把它或屏幕边缘的正常约束误写为已观察到的“松开后仍粘鼠标”。

原实现由多个子背景把拖动转给 Options 根框体，却没有显式提供当前鼠标起点；只记录 `dragging`，无来源归属；任何注册背景的 Hide/Stop 都可能结束当前会话。原保存路径还在清除归属和读取中心前先调用原生 Stop。这些是代码可核对的问题。

RC2 合入以下变化：

- `StartMoving(true)` 显式使用当前鼠标起点。起拖时不恢复旧坐标、不调用 SetPoint、不调整 Scale。
- 记录发起拖动的背景。当前来源的 Stop、来源或其祖先隐藏会结束会话，无关页面隐藏和不同旧来源的迟到 Stop 不会结束新的会话。
- 仅活动拖动期间注册全局左键松开/按下、UI 缩放、显示尺寸和离开世界事件。结束时仅注销本功能的回调，保留共享事件管理器中其他订阅。
- 先捕获可见中心和有效缩放，再清除归属并停止原生移动。重复结束或 Stop 同步回调重入无副作用。无效/受限几何不参与算术和保存，恢复已有窗口位置。
- 保留原来的 UIParent 单位换算；由 SavedVariables 单独保存 Options 位置，关闭本框体的原生位置持久化。

运行逻辑只修改 `UI/Options.lua`，另外同步版本与交付文档。Mobility、Free move、Proc、原生计时、区域 RGB/XY、导入导出逻辑、主题和战斗排队没有改写。没有新增捕获全部控件的透明层、OnUpdate、Ticker、常驻鼠标轮询或提醒拖动功能。

## API 核查与结论边界

核查使用与现有目标审查相同的固定源提交 `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`：

- [SimpleFrame API 声明](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua) 定义 `StartMoving(alwaysStartFromMouse)`，布尔参数默认 false；同时定义 StopMovingOrSizing、SetUserPlaced、SetDontSavePosition 和 GetEffectiveScale。Start/Stop 属于可受保护的框体方法；本插件仍只在脱战时开始移动自己的非受保护 Options 根框体，没有改变战斗锁。
- [暴雪 TalentSelection 原生 UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua) 使用 GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP，并在显示/隐藏生命周期内注册和注销，支持这些事件的可用性。它不能证明本插件的原生拖动事件排序或修复结果。

**开发环境没有真实 WoW 客户端。** 起点参数是与现象一致的修复方向；没有游戏内复现原生 C++ 跳位路径，也没有证明它已彻底消失。离线的中心变化、Stop 重入和秘密几何属于故障注入模型。它们验证 Lua 的防护与资源清理，不等于原生鼠标拖动已验收。

## 测试与包边界

保留 RC1 的 204 组，追加交接的 11 组与 4 组集成检查，共 **219 组实际 Lua 5.1 测试**。覆盖来源归属、窗口外释放、丢失释放后的新按下、无关隐藏、迟到 Stop、同步重入、无效几何、缩放往返、战斗/世界/分辨率边界和重复拖动资源计数。集成检查另核对共享全局事件订阅、受限参数防护、真实计时/显隐绑定不变、原生位置缓存设置及重载位置。四套既有静态检查完整保留。

最终结果、准确数量、Windows/Python/lupa/Lua 5.1 环境、源码提交及 ZIP SHA256 写入安装包旁的 `.tests.txt` / `.sha256`。测试工具来自仓库，并以 `--addon-root` 指向最终 ZIP 解压目录。安装包只保留 `CarGOUI` 与 `CarGOUI_Data`；交接测试器、补丁、开发测试和原始报告不进入用户 AddOns 目录。

## 游戏内重点复测

1. 完全退出游戏后，一起替换两个 AddOns 程序目录。保留 WTF 和全部 SavedVariables，不清空位置设置。记录客户端 build、UI 缩放和是否有其他移动窗口类插件。
2. `/cui`，交替从根窗口空白、Header、Body/侧栏空白、Appearance 滚动内容空白的不同角落起拖。开始移动时不能突然跳位，按住期间抓取点应维持合理的相对位置。
3. 把鼠标移到窗口外再松开，然后换另一个背景抓取；多次重复。松开后不得继续移动，也不能必须 `/reload` 才恢复。
4. 拖动中关闭窗口、Esc、切页隐藏来源、进入战斗、改变 UI 缩放或显示尺寸、跨世界载入后，再打开并尝试拖动。不得卡住会话；未在战斗内请求打开时，脱战不擅自弹出。
5. 检查 Center window、重新开关窗口、`/reload` 后的位置，以及按钮、滑块、数字 Enter、下拉菜单和导入文本选择/滚动。提醒坐标、字体、RGB 和真实计时应保持原样。
6. 若仍有跳位，记录起始背景、刚做过的切页/导入/缩放操作、客户端 build，并用短视频区分“起拖瞬移”与“碰到屏幕边缘后鼠标相对位置改变”。保留存档以便复现。

原生拖动验证通过后，再按 [完整 RC 验收清单](RC_ACCEPTANCE.md) 决定是否进入正式发布；本轮不会代替用户做这个发布决定。
