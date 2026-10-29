# 默认爆发技能复核：2026-10-28

数据版本：2026.10.28.1。核对方式：Terra xhigh 子代理使用 Ego 浏览器访问 Lorrgs 全部 40 专精页面，另核对其公开事件目录、已有本地 12.1.0.69933 主动技能映射与新增技能的中文提示。这里记录实际采用结果，而非将上游页面选择栏直接复制成默认名单。

## 采用规则与边界

- 未配置的大秘境首领使用 `primarySpecs`；运行时按是否学会过滤。已有个人方案不改写。
- 冰霜死亡骑士按用户明确指定：死神印记、冰霜之柱、冰龙吐息；符文武器增效退出默认，但保留旧目录元数据与手动引用兼容。
- 默认收录主要爆发及明确的进攻强化窗口，治疗保留主要治疗技能，坦克保留主要强化技能。不是完整法术书，也不是所有直接伤害技能。
- Lorrgs 图标开关是时间轴筛选，不是爆发推荐；所选首领的页面缺席不等于技能被删除，因此未据此硬删其他原有默认技能。
- 保留主动动作编号：浩劫恶魔变形191427、噬灭虚空变形1217605、增辉黑檀之力395152，不用上游效果/增益编号替换。
- 唤醒仅回资源，仍为非默认；守护万灵之召、踏风天神御身本轮仍保留非默认。魔典：邪能破坏者补入可选目录，与魔典：小鬼领主保持同级。
- 本轮验证为网页/数据及本地静态与模拟测试；未进行游戏内实战验证，未更新独立网页项目或游戏安装目录。

## 最终默认名单

以下含可选天赋，并不表示一个角色同时拥有全部技能。具体增益作用与条件以游戏内实际天赋为准。

| 职业 | 专精 | 默认技能（主动编号） | 核对页面 |
|---|---|---|---|
| 死亡骑士 | 鲜血 | 符文刃舞（49028）、死神印记（439843） | [Lorrgs](https://lorrgs.io/spec_ranking/deathknight-blood/nekzali-the-soulcoiler) |
| 死亡骑士 | 冰霜 | 冰霜之柱（51271）、死神印记（439843）、冰龙吐息（1249658） | [Lorrgs](https://lorrgs.io/spec_ranking/deathknight-frost/nekzali-the-soulcoiler) |
| 死亡骑士 | 邪恶 | 亡者大军（42650）、黑暗突变（1233448）、瘟疫降临（1271967） | [Lorrgs](https://lorrgs.io/spec_ranking/deathknight-unholy/nekzali-the-soulcoiler) |
| 恶魔猎手 | 浩劫 | 恶魔变形（191427）、精华破碎（258860）、恶魔追击（370966） | [Lorrgs](https://lorrgs.io/spec_ranking/demonhunter-havoc/nekzali-the-soulcoiler) |
| 恶魔猎手 | 复仇 | 恶魔变形（187827） | [Lorrgs](https://lorrgs.io/spec_ranking/demonhunter-vengeance/nekzali-the-soulcoiler) |
| 恶魔猎手 | Devourer | 虚空变形（1217605） | [Lorrgs](https://lorrgs.io/spec_ranking/demonhunter-devourer/nekzali-the-soulcoiler) |
| 德鲁伊 | 平衡 | 化身：艾露恩之眷（102560）、超凡之盟（383410）、万灵之召（391528） | [Lorrgs](https://lorrgs.io/spec_ranking/druid-balance/nekzali-the-soulcoiler) |
| 德鲁伊 | 野性 | 猛虎之怒（5217）、化身：阿莎曼之灵（102543）、狂暴（106951）、万灵之召（391528） | [Lorrgs](https://lorrgs.io/spec_ranking/druid-feral/nekzali-the-soulcoiler) |
| 德鲁伊 | 守护 | 狂暴（50334）、化身：乌索克的守护者（102558） | [Lorrgs](https://lorrgs.io/spec_ranking/druid-guardian/nekzali-the-soulcoiler) |
| 德鲁伊 | 恢复 | 宁静（740）、化身：生命之树（33891）、万灵之召（391528） | [Lorrgs](https://lorrgs.io/spec_ranking/druid-restoration/nekzali-the-soulcoiler) |
| 唤魔师 | 湮灭 | 狂龙之怒（375087） | [Lorrgs](https://lorrgs.io/spec_ranking/evoker-devastation/nekzali-the-soulcoiler) |
| 唤魔师 | 恩护 | 梦境飞行（359816）、回溯（363534）、静滞（370537） | [Lorrgs](https://lorrgs.io/spec_ranking/evoker-preservation/nekzali-the-soulcoiler) |
| 唤魔师 | 增辉 | 黑檀之力（395152）、亘古吐息（403631） | [Lorrgs](https://lorrgs.io/spec_ranking/evoker-augmentation/nekzali-the-soulcoiler) |
| 猎人 | 野兽控制 | 狂野怒火（19574） | [Lorrgs](https://lorrgs.io/spec_ranking/hunter-beastmastery/nekzali-the-soulcoiler) |
| 猎人 | 射击 | 百发百中（288613） | [Lorrgs](https://lorrgs.io/spec_ranking/hunter-marksmanship/nekzali-the-soulcoiler) |
| 猎人 | 生存 | 狩魂一击（1250646） | [Lorrgs](https://lorrgs.io/spec_ranking/hunter-survival/nekzali-the-soulcoiler) |
| 法师 | 奥术 | 大法师之触（321507）、奥术涌动（365350） | [Lorrgs](https://lorrgs.io/spec_ranking/mage-arcane/nekzali-the-soulcoiler) |
| 法师 | 火焰 | 燃烧（190319） | [Lorrgs](https://lorrgs.io/spec_ranking/mage-fire/nekzali-the-soulcoiler) |
| 法师 | 冰霜 | 寒冰宝珠（84714）、冰霜射线（205021） | [Lorrgs](https://lorrgs.io/spec_ranking/mage-frost/nekzali-the-soulcoiler) |
| 武僧 | 酒仙 | 玄牛下凡（132578）、爆炸酒桶（325153） | [Lorrgs](https://lorrgs.io/spec_ranking/monk-brewmaster/nekzali-the-soulcoiler) |
| 武僧 | 织雾 | 还魂术（115310）、青龙下凡（322118）、朱鹤下凡（325197）、天神御身（443028） | [Lorrgs](https://lorrgs.io/spec_ranking/monk-mistweaver/nekzali-the-soulcoiler) |
| 武僧 | 踏风 | 白虎下凡（123904）、乾元之巅（1249625） | [Lorrgs](https://lorrgs.io/spec_ranking/monk-windwalker/nekzali-the-soulcoiler) |
| 圣骑士 | 神圣 | 复仇之怒（31884）、复仇十字军（216331） | [Lorrgs](https://lorrgs.io/spec_ranking/paladin-holy/nekzali-the-soulcoiler) |
| 圣骑士 | 防护 | 复仇之怒（31884） | [Lorrgs](https://lorrgs.io/spec_ranking/paladin-protection/nekzali-the-soulcoiler) |
| 圣骑士 | 惩戒 | 复仇之怒（31884）、灰烬觉醒（255937）、处决宣判（343527） | [Lorrgs](https://lorrgs.io/spec_ranking/paladin-retribution/nekzali-the-soulcoiler) |
| 牧师 | 戒律 | 终极苦修（421453）、福音（472433） | [Lorrgs](https://lorrgs.io/spec_ranking/priest-discipline/nekzali-the-soulcoiler) |
| 牧师 | 神圣 | 神圣赞美诗（64843）、神圣化身（200183） | [Lorrgs](https://lorrgs.io/spec_ranking/priest-holy/nekzali-the-soulcoiler) |
| 牧师 | 暗影 | 能量灌注（10060）、虚空形态（228260） | [Lorrgs](https://lorrgs.io/spec_ranking/priest-shadow/nekzali-the-soulcoiler) |
| 潜行者 | 奇袭 | 死亡印记（360194）、君王之灾（385627） | [Lorrgs](https://lorrgs.io/spec_ranking/rogue-assassination/nekzali-the-soulcoiler) |
| 潜行者 | 狂徒 | 冲动（13750）、影舞步（51690）、时运继延（381989） | [Lorrgs](https://lorrgs.io/spec_ranking/rogue-outlaw/nekzali-the-soulcoiler) |
| 潜行者 | 敏锐 | 暗影之刃（121471）、暗影之舞（185313） | [Lorrgs](https://lorrgs.io/spec_ranking/rogue-subtlety/nekzali-the-soulcoiler) |
| 萨满祭司 | 元素 | 升腾（114050）、风暴守护者（191634） | [Lorrgs](https://lorrgs.io/spec_ranking/shaman-elemental/nekzali-the-soulcoiler) |
| 萨满祭司 | 增强 | 升腾（114051）、毁灭之风（384352）、始源风暴（1218090） | [Lorrgs](https://lorrgs.io/spec_ranking/shaman-enhancement/nekzali-the-soulcoiler) |
| 萨满祭司 | 恢复 | 治疗之潮图腾（108280）、升腾（114052） | [Lorrgs](https://lorrgs.io/spec_ranking/shaman-restoration/nekzali-the-soulcoiler) |
| 术士 | 痛苦 | 召唤黑眼（205180）、怨毒（442726）、幽冥收割（1257052） | [Lorrgs](https://lorrgs.io/spec_ranking/warlock-affliction/nekzali-the-soulcoiler) |
| 术士 | 恶魔学识 | 召唤恶魔暴君（265187）、召唤末日守卫（1276672） | [Lorrgs](https://lorrgs.io/spec_ranking/warlock-demonology/nekzali-the-soulcoiler) |
| 术士 | 毁灭 | 召唤地狱火（1122）、怨毒（442726） | [Lorrgs](https://lorrgs.io/spec_ranking/warlock-destruction/nekzali-the-soulcoiler) |
| 战士 | 武器 | 天神下凡（107574）、剑刃风暴（227847） | [Lorrgs](https://lorrgs.io/spec_ranking/warrior-arms/nekzali-the-soulcoiler) |
| 战士 | 狂怒 | 鲁莽（1719）、天神下凡（107574）、奥丁之怒（385059）、剑刃风暴（446035） | [Lorrgs](https://lorrgs.io/spec_ranking/warrior-fury/nekzali-the-soulcoiler) |
| 战士 | 防护 | 天神下凡（107574） | [Lorrgs](https://lorrgs.io/spec_ranking/warrior-protection/nekzali-the-soulcoiler) |

## 证据与复核说明

- 页面与接口快照：`.local/lorrgs-burst-audit-20261028/observations.json`、`api-comparison.json`；取舍报告：同目录 `report.md` 与 `candidate-review.md`。
- [Lorrgs 冰霜专精事件目录](https://api2.lorrgs.io/api/specs/deathknight-frost/spells)；其它专精接口见各页面对应的 class-spec。
- [暗影之舞中文元数据](https://nether.wowhead.com/tooltip/spell/185313?dataEnv=1&locale=4)、[精华破碎中文元数据](https://nether.wowhead.com/tooltip/spell/258860?dataEnv=1&locale=4)、[魔典：邪能破坏者中文元数据](https://nether.wowhead.com/tooltip/spell/1276467?dataEnv=1&locale=4)。三者均有对应专精的本地 `spellmap.json`。
- [死神印记中文元数据](https://nether.wowhead.com/tooltip/spell/439843?dataEnv=1&locale=4)与本地鲜血映射共同支持增加鲜血归属；不因上游共享职业条目而扩给邪恶。

本轮没有验证所有天赋组合的实时可用性；本地游戏数据版本沿用原始来源，不把访问日期伪装为新游戏版本。
