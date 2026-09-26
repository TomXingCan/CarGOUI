# Alpha.7：逐条目 Appearance 与自动主题

基于用户已实测确认 Blink / Shimmer 正常的 alpha.6（`3f903f6ac91a33232b9f36d57d9c47f03049cebb`）增量修改。此次不改 `SpellState.lua` 的战斗识别/原生显隐路径，不增加真实 Proc 或其他职业监控。开发环境没有 WoW 客户端；本次新增样式与主题的真实视觉验收仍待执行。

## 每个条目独立保存

账号级 `CarGOUIDB.styles[key]` 保存 `{ font = { face, size, outline }, shadow = { enabled }, scale }`。Blink 和 Shimmer 分别使用 `mobility_blink`、`mobility_shimmer`：同一技能跨法师专精沿用该技能样式，两个技能不联动。位置仍按原有 `mage_*_shimmer` 与未选专精位置 ID 保存，切换技能不移动已设坐标。

Proc 沿用现有七个区域 ID：奥术 Clearcasting 左/右、火焰 Hot Streak 左/右、冰霜 Fingers of Frost 左/右和 Brain Freeze 上方。不同区域的样式记录、font 子表和 shadow 子表均独立。不新增技能映射；Proc 仍只有已定义的外部模拟预览。

Mobility → Appearance 可选择 Blink 或 Shimmer。Proc → 选择当前专精的区域 → Appearance。Appearance 内可继续切换同类条目；页面使用原生滚动区域容纳全部控件。下拉、开关、滑块即时保存，精确数值按 Enter 保存。切换条目会丢弃未提交的输入；关闭窗口和换分类同样不提交草稿。`Reset this entry's style` 只将该样式恢复工厂值，不改任何坐标或其他条目。

选中尚未生效的 Blink/Shimmer 样式可以查看明确标记 TEST 的外观样例；这不改变技能学习/替换识别，也不会把样例送入实时监控。live 始终使用实际识别技能的样式。同一个条目的 live 与 Preview 读取同一个配置记录。旧全局 Font/Scale 页面与批量修改样式命令已取消；`/cui`、`/cargoui`、全局位置及显示开关保留。

## 一次性迁移

Schema 3 及更旧版本升级到 schema 4 时，先校验旧全局 font/shadow/scale，再把有效值深复制到各独立样式中缺少或无效的字段；已有独立有效值优先。每条记录分别复制，处理保存数据原先共用同一 table 的情况。字体路径规范化后仍保持原有字形、大小与缩放。

迁移完成后，旧全局字段仅作兼容历史保留，不再被渲染器继承；缺失或新增加的条目使用工厂默认值（Friz Quadrata / 24 / OUTLINE / Shadow on / Scale 1），不读取上次编辑条目或旧全局值。再次登录不会覆盖有效的独立设置。位置、窗口位置、开关及未知配置字段继续保留，不清空 SavedVariables。

`LayoutReminder` 只应用当前条目的 scale 一次，再按该 scale 补偿锚点偏移，避免大小变化带动锚点。真实框体与文字区域使用当前条目字号计算固定尺寸，受限数字不参与尺寸测量。Preview 的原版形状引导以对应条目 scale 的倒数保持原大小。

`RefreshReminderStyle(key)` 只更新该 key 对应的缓存框体。样式编辑不重新查询冷却、不调用 `SetDuration`、不读原生文字/alpha、不重置已有计时、不重设原生显隐透明度。名称与数字继续由共用职业色逻辑调用 `SetTextColor`，没有颜色选择器，也不保存角色 RGB。

## 自动主题

打开 Options 解析阵营、职业和专精；窗口可见时监听必要身份事件，隐藏后解除主题自己的回调。主题与 Mobility 共享事件框架，但不会解绑 Mobility 的订阅。无手动主题选择、Apply Theme 或主题颜色编辑。

联盟奥法为用户指定的深色底、红→奥术紫。另五种组合及明确的中性/法师回退方案见 [主题映射与 API 核查](THEMES.md)。颜色集中在 `Database/Themes.lua`，使用原生静态渐变、少量复用的低透明度几何纹理和原有品牌强调色接口，不染色整张蓝金 Logo。标题动画开关及进战斗停止动画规则不变。

## 游戏内验收

替换 AddOn 文件，保留 WTF/SavedVariables。登录后确认版本 `0.1.0-alpha.7`，先检查升级前后的字体大小、坐标与窗口位置相同。打开 `/cui`。

| 项目 | 操作与预期 |
| --- | --- |
| 1. Mobility 独立 | 修改 Blink 字体/大小/描边/阴影/缩放，Shimmer 和全部 Proc 不变；切到 Shimmer 后看到它自己的值。 |
| 2. Proc 区域独立 | 修改一个左侧 Proc 的字号，右侧同效果及其他 Proc 不变。整个 Proc 页面明确 Preview only。 |
| 3. 同条目一致 | 比较同技能的外部 TEST 与实际耗尽输出，字体、大小、描边、阴影、缩放和固定职业色一致。 |
| 4. 草稿、专精、重载 | 输入字号但不按 Enter，切条目后不串值；返回原条目仍是已保存值。切专精和 `/reload` 后独立值保留。 |
| 5. 升级保真 | 使用原有非默认字体/大小/scale/偏移升级，外观和锚点不变。分别改条目，确认无联动；重置当前样式不影响位置。离线另验证 table 不共享。 |
| 6. 联盟奥法 | Alliance Arcane 自动出现深色红→奥术紫；Themes 只显示 Automatic 与识别结果，无手动选择。 |
| 7. 切专精 | 可见时切专精，Options 自动换对应主题；所有提醒样式和坐标保持保存值。关闭后切换，再打开时立即采用新身份。 |
| 8. 回退 | 未选专精、未选阵营或未覆盖身份，明确使用中性/职业回退，不误用奥法等专精主题。无法获得该角色条件记“未覆盖”。 |
| 9. 战斗回归 | Blink/Shimmer 战斗内外仍是有一次可用不显示，耗尽显示真实下一次恢复，恢复一次立即不可见。关闭 Options/Stop test 后继续。 |
| 10. 活跃计时改样式 | 耗尽计时中修改该技能外观，数字继续原进度，锚点不移动，没有闪烁、恢复完整 CD 或 secret/taint 错误。修改其他条目不触及这段计时。 |

还需目视检查 Appearance 滚动区底部的 Reset / Preview / Back 都可操作、主题渐变和正文对比清楚、标题品牌保持原字形，以及动画关闭/战斗中静止。没有测试条件的组合应记录未覆盖。

离线测试与静态检查、最终 ZIP 解包测试结果见 `CarGOUI-alpha.7-Test-Results.txt`。离线 native API doubles 只能验证脚本契约，不能替代真实客户端 secret/taint、渐变渲染、输入焦点和视觉排版验收。用户已确认的是升级前战斗行为，本轮不会把它自动记为新包全部验收通过。
