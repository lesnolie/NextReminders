# 内置爆发技能目录

2026-10-13，NextReminders 0.3.4-dev，dataVersion=2026.10.13.1。STATIC/MOCK和WEB不等于游戏LIVE；本项目48项检查通过，LIVE尚未运行，source_review=PENDING。

范围：40个专精的122个去重主动技能。输出专精覆盖主要进攻爆发及短爆发；治疗加入主要治疗爆发，坦克加入主要强化技能。不是完整法术书，也不是自动输出循环；药水／饰品仍用原有物品、栏位或文字提醒。目录包含可选天赋／替代动作，网页按专精展示，玩家按自己的天赋选择。没有预置任何首领打法、自动填提醒行或固定冷却秒数。

来源与核对：

1. CoolPlan的公开浏览器构建数据作为候选：[专精页](https://coolplan.team/spec-benchmark/DeathKnight/Frost?dungeon=murder-row)，[包含目录的公开JSON数据构建块](https://coolplan.team/_next/static/chunks/7597-4806b1d5056ccdcb.js)。源表自身将12.1验证标为pending，因此没有原样采用其全部技能、专精归属或冷却数值，也未复制其程序逻辑或技能说明。
2. 本机游戏数据图标库 `C:/work/TMN/TMN/resources/wow_spell_icons_by_spec` 的index.json与recommended.json，版本12.1.0.69933，类别action_bar_spells_only，40专精。只复制通过SHA256核对的游戏图像，并核对每个入库技能的专精归属。该库的推荐名来自SpellName与[SimulationCraft](https://github.com/simulationcraft/simc/tree/fa7a6dc693fee5d478addb9df97e479153567fa1/ActionPriorityLists/default)；只用来核对主动动作，未采用APL顺序作为玩家方案。
3. [Wowhead中文技能元数据](https://nether.wowhead.com/tooltip/spell/1233448?dataEnv=1&locale=4)补齐122条中文名与原生纹理名；同格式逐编号读取。完整技能描述不进入产品，冷却秒数也不进入目录。取回原始元数据在.local/burst-catalog-20261013，交付不依赖该目录。

入库纠正：浩劫恶魔变形效果编号200166改为主动191427；噬灭虚空变形效果编号1217607改为主动1217605；亘古吐息442204改为动作403631；武器战士剑刃风暴采用主动227847，狂怒保留该专精动作446035。CoolPlan中的旧冰冷血脉／野性狼魂等不在本地12.1动作库的候选未默认加入；排除清单留在.local。使用实际游戏API显示名称／图标的优先级高于目录；这不构成所有天赋组合的LIVE可施放验证。

领域边界：相同名字或图标不构成等价施法编号证据。目录只提供显示与选择，不把这些编号建立成引擎别名，不改变施法撤提醒或冷却监听的匹配规则。天赋替代项显式选择，各自导出本身编号；未来需要跨编号跟随时单独补机制证据和测试。

维护：`web/burst-spells.json`是独立可维护源。修改后运行`python tools/sync_spell_catalog.py`生成`web/spells.mjs`和`NextReminders/SpellCatalog.lua`，再运行`python tests/check.py`与`python tools/build.py`。`--check`验证生成文件和源一致，编译时无联网或上游插件依赖。源JSON保存来源版本、原始数据哈希和每条归属，不保存推测冷却时长。

网页验证：冰DK六个技能均有本地图像，点选冰霜之柱导出51271；换成冰龙吐息立即清除旧文本并禁止复制。所有新行不自动选技能，手填目录外编号继续可用。目录提示明确40专精覆盖。插件验证：40专精选取目录技能实际JS导出→Lua解析→Engine→成功施法撤当前提醒；公开本地游戏名称优先，API为空／异常／秘密字段时用目录名称和纹理；未知自定义技能仍显示编号并允许导入。`/nr spells`列当前专精目录，不生成／保存策略，也不改战斗状态。

额外WEB核对：目录外编号999999未失焦即显示技能999999并可导出；重新输入1249658立即显示冰龙吐息及本地图像，清掉旧生成快照。修复NR-ERR-024。390宽选择器无页面横向溢出。0.3.4安装前与现有0.3.3全Lua／TOC逐字节核对，旧文件ZIP备份后同步7个变化文件（含新增SpellCatalog.lua），15个Lua与TOC和构建快照一致；不修改SavedVariables。游戏须/reload，实际所有天赋组合仍未LIVE验证。
