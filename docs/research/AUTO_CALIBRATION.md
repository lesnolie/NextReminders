# 自动校准可行性与公开源码调查

日期：2026-10-12。对应产品现状0.1.3-dev；本次是调查与设计说明，不代表自学习已经实现。没有修改插件、接入新运行依赖或重打包。

## 公开源码入口

已找到 [bart-dev-main/TimelineReminders-Public](https://github.com/bart-dev-main/TimelineReminders-Public)，GitHub API确认public=true、默认master。

核对HEAD为 `69800a5e305c48293adddd63e7f8543e2715cde6`，[提交页](https://github.com/bart-dev-main/TimelineReminders-Public/commit/69800a5e305c48293adddd63e7f8543e2715cde6)对应2024-11-15。公开 [TOC](https://github.com/bart-dev-main/TimelineReminders-Public/blob/69800a5e305c48293adddd63e7f8543e2715cde6/TimelineReminders_Mainline.toc) 声明版本1.55、Interface110002；递归目录接口truncated=false，仅有根TimelineData.lua，没有TOC列出的TimelineData目录和当前Midnight首领文件。它是旧公开代码，不能当作v453完整源码或当前首领数据库。

GitHub仓库名称检索本次返回2个结果；另一个CooperWebDev/TimelineReminders的HEAD为d62ed0ec34f17f660ccef9f309173afaa33d47a1，完整树只有3个文件，未包含TOC/Midnight/阶段逻辑，不是当前目标的完整实现。作者bart-dev-main公开仓库列表中未发现另一份新版源码。本次限定检索范围没有找到v453的公开仓库，不推断整个互联网不存在，也不将404等同确定私有。

用户已有v453 ZIP本身包含可读Lua，含我们调查过的首领文件；其CHANGELOG的v453条目日期2026-09-02，指向bart-dev-wow/TimelineReminders的v453树与比较页。之前调查只确认该地址不可公开访问，不能推出所有版本都没有公开源码。新找到的旧公开入口纠正了这一范围遗漏。

后续仍按用户选择独立维护，不恢复原包自动获取路线。

## 可观测数据与事实限制

[暴雪生成时间轴接口定义](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterTimelineDocumentation.lua)将事件实例id/source/duration/maxQueueDuration列为NeverSecret；spellID/name等不保证公开。实例id不是技能编号，不应跨场当作稳定技能身份。

状态Finished/Removed只是时间轴事件生命周期信号，不能未经逐机制核对就当作实际首领施法或效果生效。Removed在终态后至少延迟一个游戏tick，事件移除后GetEventInfo查询返回nil；单用移除时点学习会混入移除延迟或取消。

不同机制可能具有相同时长；仅以时长或靠近预计时间进行匹配，无法独立证明机制身份。玩家冰柱/吐息施法时点是个人安排，也不能作为心脏或易伤真实生效时间的标签。

## 当前插件能力

Engine.Begin每场重置内存trace，最多500条；Main仅向阶段引擎传公开实例编号、来源和时长，状态变化只处理Canceled。尚无持久战斗样本、独立真实标签、误差统计或参数学习。已有阶段相对提醒能在识别到节点时以本场节点起点计时，但这不等于跨场自学习。

BossData.fixed目前只是预览参考；个人导入提醒仍由rows.time与phaseBindings决定。只改首领固定表不会自动调整开战相对个人方案。

原v453 Display/Display.lua包含OffsetQueuedReminders、PauseActiveReminders、ContinueActiveReminders：可按已有规则纠正本场队列。查看该代码与MidnightPhaseChanger不能证明其会自动发现任意新机制或跨场训练。

## 推荐实现路线（尚未实施）

1. **持久采集**：保存公开新增/状态变化/移除、阶段候选、预测时点、独立确认时点；按首领、准确难度、游戏构建、机制与轮次分组。记录采样完整性、起点来源与模拟标志，不采集秘密字段。
2. **可靠标签**：优先采用事先核对的公开机制信号；无法确定身份的事件以匿名样本保留。离线战斗日志、录屏或人工阶段标记可以提供独立标签。插件自己的预测和同一套待验证规则输出不作真值。
3. **本场同步**：已确认节点实际发生后重设该段起点，未来机制/提醒使用节点相对时间；不把整场所有提醒机械平移。不能追溯修正已经响过的提醒。
4. **跨场参数校准**：对已确认机制的相对时点或间隔计算中位数与误差分布，降低偶发延迟的影响；足够多且独立的新样本验证误差确实下降后，以受限步长更新下一场参数。阈值由实测定，不宣称任意固定样本数足以保证准确。
5. **阶段规则候选**：比较阶段前后公开事件组合、时长、取消序列和上下文；新规则只在后台并行计算，不先接管真实提醒。用未参与拟合的已标注战斗检查误报/漏报及起点误差，通过后版本化采用；突然漂移冻结旧学习并保留可回滚参数。

示例仅说明计算：某已独立确认的心脏机制原预测129秒，多场有效样本集中129.4～129.6秒，可形成129.5秒的候选参数；另一次异常延迟不应直接把预测改成异常值。英雄与史诗、不同补丁和第几次心脏各自建模。若阶段由击杀速度或打断决定，优先学习相对可靠节点的间隔，不把所有场次的绝对秒数混成一个均值。

预览/手动模拟不参与学习；中途结束后未观察到的机制不记为零或错误；重复事件只计一次。持续缺少可靠标签时只采集并报告变化，不能宣称会自己越来越准。

## 将准确度传递到个人提醒

后续需要真正的机制节点绑定，例如“确认心脏开始后3秒”，并标明起点是施法开始还是易伤开始。采集及校准作用于机制模型，玩家的相对偏移继续由个人方案决定。现版“开战后135.5秒”不会自动变成机制相对提醒，Lorrgs导出的来源阶段也不能自动等同游戏实时阶段。

## 验证边界

调查已验证公开仓库身份/版本/HEAD和本地当前代码。算法路线为设计建议，未实现、未MOCK验收、未LIVE实测。当前发行包仍为0.1.3-dev及原有21项自检证据，不宣称新增自学习功能。
