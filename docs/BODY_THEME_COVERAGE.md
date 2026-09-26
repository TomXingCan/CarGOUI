# Body 自动主题覆盖表

本轮扩展的是 **Options 外观**：13 个职业基础主题、40 个职业／专精主题，以及未知身份的中性回退。职业与专精只决定 Body；Header 继续只根据阵营使用联盟蓝、部落红或中性色。

**这不等于全职业 Mobility 支持。** 真实位移监控仍只有已实现的法师 Blink / Shimmer；本轮没有加入其他职业技能监控、真实 Proc、技能映射或提醒配置。提醒职业色、独立配置范围、坐标和真实计时逻辑均不在此主题数据文件内。

以下所有新增职业配色与几何图案都是本轮的原创设计提案，不是用户逐项指定的艺术方案。法师奥术／火焰／冰霜的配色和水印端点数据保持 alpha.9 原样。用户此前确认了 alpha.9 的法师界面；**本次交付包尚须真实客户端回归，不能把旧版本验收当成本包已经验收。**

## 职业基础主题：未选择专精或专精未覆盖时

每个已知职业都有自己的可见基础主题，不套用其他职业或错误专精。表中的“待实测”指真实客户端视觉与交互验收；代码和离线验证状态应结合随包测试结果阅读。

| 职业 | Body key | 深色渐变／强调方向 | 基础水印 | 实现状态 | 实机验收状态 |
| --- | --- | --- | --- | --- | --- |
| 死亡骑士 | `deathknight` | 深暗红铁色 → 符文紫红 | 符文长剑、两侧菱形印记 | 已实现 | 待实测 |
| 恶魔猎手 | `demonhunter` | 深墨绿 → 邪能翡翠 | 成对战刃、眼罩式横线、中央印记 | 已实现 | 待实测 |
| 德鲁伊 | `druid` | 深林绿 → 草木琥珀 | 鹿角、叶片、树脉 | 已实现 | 待实测 |
| 唤魔师 | `evoker` | 深青黑 → 龙族翡翠 | 龙翼、龙首、弯曲尾线 | 已实现 | 待实测 |
| 猎人 | `hunter` | 深森林色 → 橄榄绿 | 弓弦、箭矢、菱形狩猎印记 | 已实现 | 待实测 |
| 法师 | `mage` | 保留深色法师蓝灰 | 通用法球、光芒与法杖；不是任意专精图案 | 已实现 | 待实测 |
| 武僧 | `monk` | 深青绿 → 翡翠 | 相交圆环、中央菱形气印 | 已实现 | 待实测 |
| 圣骑士 | `paladin` | 深暖棕 → 克制金色 | 护盾、战锤、中央印记 | 已实现 | 待实测 |
| 牧师 | `priest` | 深暖灰 → 象牙暗金 | 光环、权杖、两侧衣褶线 | 已实现 | 待实测 |
| 潜行者 | `rogue` | 炭黑 → 黄铜 | 交叉匕首、中央印记 | 已实现 | 待实测 |
| 萨满祭司 | `shaman` | 深风暴蓝 → 钴蓝 | 圆环、闪电、外侧菱形图腾 | 已实现 | 待实测 |
| 术士 | `warlock` | 深紫黑 → 邪能紫晶 | 传送环、弯角、中央符印 | 已实现 | 待实测 |
| 战士 | `warrior` | 深铁灰 → 锈铜 | 交叉长剑、中央军徽 | 已实现 | 待实测 |

## 逐专精覆盖

同职业的专精不只改变标签：每条记录都有独立配色和不同的水印线段组合。相同职业保留基础识别轮廓，再加入对应专精的图案变化。所有图案都是抽象主题符号，不代表实时技能、Buff、冷却或可用状态。

| 职业 | specID／专精 | Body key | 深色渐变／强调方向 | 水印变化 | 实现状态 | 实机验收状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 死亡骑士 | 250 Blood | `deathknight_blood` | 暗血红 → 深绯红 | 剑身血滴形符印 | 已实现 | 待实测 |
| 死亡骑士 | 251 Frost | `deathknight_frost` | 深冰钢蓝 → 霜蓝 | 两侧六向冰芒 | 已实现 | 待实测 |
| 死亡骑士 | 252 Unholy | `deathknight_unholy` | 暗苔绿 → 瘟疫绿 | 两侧骸骨式角面符印 | 已实现 | 待实测 |
| 恶魔猎手 | 577 Havoc | `demonhunter_havoc` | 暗绿 → 酸性邪能绿 | 战刃上方裂焰、下方四向气芒 | 已实现 | 待实测 |
| 恶魔猎手 | 581 Vengeance | `demonhunter_vengeance` | 焦褐 → 灼热铜金 | 战刃中央护盾 | 已实现 | 待实测 |
| 恶魔猎手 | 1480 Devourer | `demonhunter_devourer` | 深虚空蓝紫 → 紫罗兰 | 战刃中央虚空圆环与菱形核心 | 已实现 | 待实测 |
| 德鲁伊 | 102 Balance | `druid_balance` | 月夜靛蓝 → 星紫 | 鹿角间新月轮廓 | 已实现 | 待实测 |
| 德鲁伊 | 103 Feral | `druid_feral` | 树皮暗棕 → 野性锈橙 | 双侧三重爪痕 | 已实现 | 待实测 |
| 德鲁伊 | 104 Guardian | `druid_guardian` | 深土棕 → 古铜金 | 中央兽掌印 | 已实现 | 待实测 |
| 德鲁伊 | 105 Restoration | `druid_restoration` | 深树叶绿 → 新生翡翠 | 双侧新叶 | 已实现 | 待实测 |
| 唤魔师 | 1467 Devastation | `evoker_devastation` | 暗宝石红 → 深龙翼蓝 | 龙翼下方双重裂焰 | 已实现 | 待实测 |
| 唤魔师 | 1468 Preservation | `evoker_preservation` | 深翡翠 → 青铜绿 | 双侧生命叶片 | 已实现 | 待实测 |
| 唤魔师 | 1473 Augmentation | `evoker_augmentation` | 黑曜石棕 → 青铜金 | 双侧带切面的菱形晶体 | 已实现 | 待实测 |
| 猎人 | 253 Beast Mastery | `hunter_beastmastery` | 深蕨绿 → 草木琥珀 | 弓箭下方兽掌印 | 已实现 | 待实测 |
| 猎人 | 254 Marksmanship | `hunter_marksmanship` | 深林钢蓝 → 青蓝 | 箭矢前方瞄准环和刻度 | 已实现 | 待实测 |
| 猎人 | 255 Survival | `hunter_survival` | 暗苔绿 → 锈铜 | 斜向长矛与陷阱式菱形 | 已实现 | 待实测 |
| 法师 | 62 Arcane | `arcane` | 深紫 → 奥术紫 | 原有双圆环、中央符印、四向符文；60 条线 | 已实现，保留 alpha.9 | 用户确认 alpha.9；本包待回归 |
| 法师 | 63 Fire | `fire` | 深红棕 → 暗琥珀 | 原有外焰和内焰；27 条线 | 已实现，保留 alpha.9 | 用户确认 alpha.9；本包待回归 |
| 法师 | 64 Frost | `frost` | 深蓝 → 冰青 | 原有中心晶体、六向冰枝；36 条线 | 已实现，保留 alpha.9 | 用户确认 alpha.9；本包待回归 |
| 武僧 | 268 Brewmaster | `monk_brewmaster` | 暗琥珀 → 金翡翠 | 相交气环中的酒桶轮廓 | 已实现 | 待实测 |
| 武僧 | 269 Windwalker | `monk_windwalker` | 深天青 → 青蓝 | 外侧流转气弧与箭尾 | 已实现 | 待实测 |
| 武僧 | 270 Mistweaver | `monk_mistweaver` | 深海绿 → 翡翠绿 | 气环上下的雾浪 | 已实现 | 待实测 |
| 圣骑士 | 65 Holy | `paladin_holy` | 暖暗金 → 光辉琥珀 | 盾上日轮与放射光芒 | 已实现 | 待实测 |
| 圣骑士 | 66 Protection | `paladin_protection` | 深蓝钢 → 淡金灰蓝 | 双层护盾 | 已实现 | 待实测 |
| 圣骑士 | 70 Retribution | `paladin_retribution` | 暗绯红 → 复仇金铜 | 护盾两侧交叉审判剑 | 已实现 | 待实测 |
| 牧师 | 256 Discipline | `priest_discipline` | 暗蓝 → 金紫灰 | 权杖旁的成对菱形和秩序横线 | 已实现 | 待实测 |
| 牧师 | 257 Holy | `priest_holy` | 深象牙棕 → 温暖暗金 | 光环外放射光芒 | 已实现 | 待实测 |
| 牧师 | 258 Shadow | `priest_shadow` | 深紫黑 → 暗影紫 | 权杖两侧虚空弧线 | 已实现 | 待实测 |
| 潜行者 | 259 Assassination | `rogue_assassination` | 深毒草绿 → 酸性橄榄绿 | 三枚毒滴形符印 | 已实现 | 待实测 |
| 潜行者 | 260 Outlaw | `rogue_outlaw` | 暗黄铜 → 深海青 | 匕首中央航向罗盘 | 已实现 | 待实测 |
| 潜行者 | 261 Subtlety | `rogue_subtlety` | 午夜蓝 → 隐秘紫 | 中央暗眼轮廓 | 已实现 | 待实测 |
| 萨满祭司 | 262 Elemental | `shaman_elemental` | 暗熔岩红 → 风暴靛蓝 | 闪电旁的火焰与岩石印记 | 已实现 | 待实测 |
| 萨满祭司 | 263 Enhancement | `shaman_enhancement` | 深钢蓝 → 闪电青 | 双侧附加闪电 | 已实现 | 待实测 |
| 萨满祭司 | 264 Restoration | `shaman_restoration` | 深潮蓝 → 海水青 | 三层潮汐波纹 | 已实现 | 待实测 |
| 术士 | 265 Affliction | `warlock_affliction` | 暗病绿灰 → 诅咒紫 | 门环中的相连锁印 | 已实现 | 待实测 |
| 术士 | 266 Demonology | `warlock_demonology` | 深紫晶 → 邪能紫红 | 角面内印和上方符核 | 已实现 | 待实测 |
| 术士 | 267 Destruction | `warlock_destruction` | 暗余烬红 → 焦灼铜金 | 门环中央烈焰 | 已实现 | 待实测 |
| 战士 | 71 Arms | `warrior_arms` | 暗绯红 → 武器青铜 | 交叉剑中央的竖直长剑 | 已实现 | 待实测 |
| 战士 | 72 Fury | `warrior_fury` | 深赤红 → 暴怒余烬 | 剑间裂焰 | 已实现 | 待实测 |
| 战士 | 73 Protection | `warrior_protection` | 深铁蓝 → 淬火钢蓝 | 剑间护盾 | 已实现 | 待实测 |

## 回退与边界

主题覆盖与真实监控分别记录：

| 范围 | Body 主题 | 真实 Mobility | 真实 Proc |
| --- | --- | --- | --- |
| 法师三系 | 已实现，保留已确认的原设计 | 现有 Blink / Shimmer；本包仍需战斗回归 | 未实现，仅已有预览 |
| 其余 12 职业／37 专精 | 全部已实现，逐项待实机视觉验收 | 当前源码尚未实现 | 未实现 |

### 游戏内验收顺序

1. 保留 WTF / SavedVariables，用本包替换两个程序目录。打开 `/cui`，在已有 Theme 页核对职业、专精、Header、Body 名称。
2. 逐项检查表内新增主题：主体大面积渐变、侧栏／底部层级、水印身份、普通文字和控件可读性；分别记录实际客户端 build 与验收结果。
3. 同阵营切专精，Body 配色／图案应变化，Header 与原品牌动画规则保持不变；换职业角色后不得残留前一职业图案。
4. 关闭 Mobility 和 Preview，或使用未学位移／尚无真实监控适配器的角色，主题仍正确。未选专精角色显示本职业基础主题。
5. 反复切换、关闭／打开窗口，检查图案不叠加；在不同 UI 缩放和分辨率下检查边界。验证拖动空白区域、输入 Enter 和滑块操作。
6. 回到法师，核对原有字体、坐标、职业色及两种位移的战斗耗尽／恢复一次即隐藏。主题变化不能重启计时。
7. 使用原有诊断快照记录实际客户端资源变化；离线对象计数不是 CPU／内存实测。

### 自动回退与运行边界

- 已知职业没有选择专精：使用该职业的基础 Body，而不是中性空白或某个假定专精。
- 已知职业遇到未知、未覆盖、受限或不属于该职业的 specID：使用该职业基础 Body，并显示回退说明。
- 职业未知或受限：使用 `neutral`；不显示误导性的职业／专精水印。
- 阵营未知只影响 Header。阵营切换不更改 Body；专精切换不更改 Header。
- 原有 64 个原生 Line 对象继续复用。选中的图案才生成端点列表，没有为 40 个专精预建框体、Line 池或图片缓存。所有端点位于中心 ±100 的设计范围内，本轮最大图案仍为 60 条线。
- 13／40 的表是轻量外观身份数据，集中随主题文件载入；不把它描述成“其他职业主题数据完全未加载”。生成当前图案和激活实际技能监控是不同职责。
- 配色表只供 Options 使用，不写入 SavedVariables，不查询技能、充能或 Buff，也不改变职业色、提醒样式、位置、透明度和 DurationTextBinding。

## 名单与接口依据

40 项名单包含 Demon Hunter **Devourer = 1480**，不是按旧版 39 专精名单推测补齐。名单核查使用 Retail **12.1.0 / build 69933** 的固定源码版本 `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`：

- [Blizzard_ClassSpecializationsFrame.lua：职业专精展示名单](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/ClassSpecializations/Blizzard_ClassSpecializationsFrame.lua)
- [Blizzard_ClassTalentUtil.lua：SpecializationVisuals 交叉核对](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentUtil.lua)

静态渐变和原生 Line 接口沿用已核查路径，见 [THEMES.md](THEMES.md)。新增几何轮廓是本项目代码原创图形；没有复制以上客户端的图标、纹理或艺术资源，也没有引用第三方插件美术。

开发目录已通过 102 项离线测试与主题静态检查，覆盖名单、显式职业／专精归属、独立配色与几何、端点范围、64 Line 上限，以及法师三系原数据不变；160 次主题切换后仍复用同一 Line 池。最终安装包的解压测试结果以随包测试报告为准。真实客户端需继续验收各职业主题的辨识度、字体可读性、不同 UI 缩放下的水印、切换专精和反复开关窗口后的对象复用；这些离线检查不能代替实际显示验收。
