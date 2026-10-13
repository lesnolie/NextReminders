# 网站导出与插件粘贴合同（0.3.1）

2026-10-12，schema 2，兼容1；source_review=PENDING，LIVE未测。

当前网站只生成大秘境整副本方案。团本直接从Lorrgs复制MRT／NSRT进插件；原单首领NRPlan:1/2、MRT／NSRT解析路径继续兼容。程序库中的旧通用导出与WCL解析仅保留给开发工具和兼容回归，网页不提供这些功能。

整副本格式：

```text
NRDungeon:1;DungeonID:2813;Difficulty:mythic;SpecID:252;Name:MurderRow;
NRPlan:2;EncounterID:3101;Difficulty:mythic;SpecID:252;Name:Boss1;
anchor:start;occurrence:1;time:0.0;window:10;spellid:1233448;
anchor:vuln;occurrence:1;time:0.0;window:10;spellid:42650;after:ready;
NRPlan:2;EncounterID:3105;Difficulty:mythic;SpecID:252;Name:Boss4;
anchor:dog;occurrence:1;time:0.0;window:10;spellid:42650;
```

DungeonID是游戏实例编号，由双方相同的副本目录校验，不是WCL排行ID或挑战地图ID。整包仅mythic（M+），一个专精、1～目录首领数份非空NRPlan，首领不能重复或跨副本。整个文本上限200KB，内部每首领最多100条；未知、重复、无效字段或任一无效首领使整包失败，不部分保存。

SaveDungeon代表此专精／副本的完整事件方案，未列出的首领旧事件规则清除；其他副本、专精、难度不变。完整备份含“原先不存在”的false状态，可整包交换回滚。另记录对应M+范围接管旧静态方案，旧文本保留存档，回滚恢复接管状态；这样未配置首领不会意外回退旧提醒。普通史诗场次不加载新包。配置页面和导入检查都说明替换范围。

网页只在点击生成时产生文本快照；任何配置输入变化立即清除旧输出、禁用复制，避免复制过期内容。空白首领可保留草稿，但不能生成整份空方案。

完整格式示例：

```text
NRPlan:2;EncounterID:3101;Difficulty:mythic;SpecID:252;Name:Unholy;
anchor:start;occurrence:1;time:0.0;window:10;spellid:1233448;
anchor:vuln;occurrence:1;time:0.0;window:10;spellid:42650;hold:Wait;after:ready;
anchor:vuln;occurrence:1;time:0.0;window:10;text:Use%20potion;
```

一个头部、一只首领/一种难度/一个专精，1～100行，最多200KB。头部必须版本1或2；重复/未知字段拒绝。EncounterID是游戏首领编号，SpecID是游戏专精编号，difficulty为normal/heroic/mythic。WCL排行编号是另一字段，通过网站/WCL工具的rankingID映射，不能改游戏EncounterID来匹配排行。

行包含anchor（start或此难度已定义的自有事件）、occurrence（1～20或every，start只能1）、time（0～3600秒，一位小数）、window（0.1～60秒）。动作恰好一种：spellid、itemid、slot（13/14）、text。name/text/hold使用encodeURIComponent的UTF-8百分号编码，解析仅还原字节，不执行代码；非法百分号编码拒绝。

提醒窗口为[eventTime+time, eventTime+time+window)，提前settings.lead显示。等待条无声、不倒数、不发光；事件可预计时开始正常提醒。第N次与每次区分，已用技能只消费当前显示的动作，不能消费未来同技能。暂停计时撤旧预报、直到Finished重定时；已经使用的行不因重定时重弹。Finished不是独立机制真值，预测/观察都不进入自动学习。

自有事件定义在BossData.events[difficulty]，与个人方案分开更新。当前密谋老一vuln是公开severity=1预警后1.7秒的候选时点；不是把取消计时的旧阶段起点当易伤。密谋老四dog用10秒计时和15/10/24批次，分体/召蛇仍待核对。所有映射均需本插件LIVE核对。

网站支持40专精、8副本28首领的手动安排，目录来自可核对的首领身份事实，非机制全覆盖声明。0.3.1新草稿的所有首领均为空白，专精／副本／首领由用户自行选择；网页仅生成字符串，移除模拟与默认打法。游戏播放预览仍可使用。首领事件仅使用BossData已存在映射，未接入首领只提供start。新目录增加时同时更新Lua/JS及合同测试。

验证：tests/check.py覆盖JS生成→Lua完整解析→UI保存→多首领Main加载、原子失败、上下文隔离、整包暂停／回滚和预览切换。36项旧回归与6项整副本回归共42项。WEB另查实际生成、空／无效输入、实时编辑失效、500宽／1440宽及脚本MIME。LIVE未测。

0.2.1后续模式：NRPlan:2可带after:ready，仅第一次的技能行，同一技能只能一处。schema1拒绝此新增字段；网站含后续就绪时拒绝通用有损导出。首次提醒实际用过才监听公开冷却状态，cooling→ready发一次语音；停止/战斗结束/进入世界全部清理。充能为全部恢复，物品/饰品/文字暂不支持。手动预览不是实际冷却预测，LIVE仍待核对。
