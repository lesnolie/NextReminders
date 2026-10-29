# 独立维护流程

> 网页项目：`C:\work\tellmenext-web`；线上入口：https://tellmenext.cc/zh/mplus/ 。本仓库只维护游戏插件，旧 `web/` 已于 2026-10-24 移除。网页修改、预览、构建与发布均在 tellmenext-web 项目进行。
> 以下旧网页说明仅为历史记录，不作为当前开发入口。插件数据维护源已迁至 `data/`；`tests/fixtures/protocol/` 仅用于旧格式兼容测试。

从 0.1.2-dev 起，不再获取 TimelineReminders。其早期调查作为历史来源保留；当前实现、测试、打包与后续首领支持由本项目独立维护。

## 首领固定时间

在 `NextReminders/BossData.lua` 修改相应首领 `fixed` 的 times/timesHeroic/timesMythic、castDuration 或 window，注明该时点对应施法开始、效果开始还是效果结束。证据来自自己的游戏测量或可核对的日志，不把单次玩家施法自动当成首领机制。

使用独立版本 `dataVersion`，格式为年.月.日.递增号。该版本显示在配置页，保存方案时作为元数据记录。旧个人方案保留原秒数。

## 公开事件阶段识别

1. 在实际战斗记录 `/nr log` 的公开新增/取消实例、时点、时长和已有节点，现场复制保留；观察真实阶段发生时刻。
2. 在难度、首领版本一致的多次战斗中核对规律，包括取消顺序、0.3 秒批次窗口、重复事件和近似时长。秘密字段不进入判断。
3. 为 BossData 中的 rules/anchors/guard 提供明确依据。当前动态机制只支持表列史诗/大秘境；若要支持英雄，先增加对应难度数据与运行选择合同，不能直接删掉难度校验。
4. 将已核对的公开事件序列写入 `tests/check.py`，通过真实 Engine:Timeline 回放，包含不会触发的反例。阶段编号、含义及循环计数一起确认。
5. 在游戏实测之前仍标记 LIVE 未测。手动播放阶段只验证提醒行为，不能证明阶段识别准确。

## 预览与测试

日常开发用自己的 Lua 数据和 MOCK，不依赖历史原包：

```powershell
python -m pip install -r requirements-dev.txt
python tests/check.py
python tools/build.py
```

当前 tests/check.py 既验证自有数据结构，又运行真实 Lua 5.1 提醒/导入/预览逻辑。新增测试接入同一入口。实际游戏界面、声音、受保护框体及节点时刻另做 LIVE 验证。

修改程序版本时同时更新 Core.lua、TOC 和使用说明。每次确认并修复错误更新 ERROR_LOG；修改接口同步 ARCHITECTURE。构建 manifest 将本次真实测试结果绑定到源码快照。执行者交付保留 source_review=PENDING，等待 Advisor 检查实际版本。

## 副本目录与生成器（0.3.0）

新增副本时，先核对游戏实例ID、全部首领EncounterID及顺序，更新DungeonData.lua和web/dungeons.mjs；来源记录在research/DUNGEON_CATALOG。原目录测试必须验证两个环境相同，首领编号不能用WCL或手册ID代替。目录不带计时和识别，特殊事件仍先补BossData证据和回放。

网站仅配置大秘境。不要重新添加团本编辑／自动Lorrgs抓取；团本继续直接粘贴导出。首领空白、包内任一无效数据、旧静态并行来源、完整替换与回滚、普通史诗／M+隔离，以及生成后实时编辑失效，都是必要反例。

0.3.1网页只负责配置并生成字符串：专精／副本／首领手动选择，不添加模拟、自动推荐或默认专精技能。新草稿必须对所有专精为空白；旧的用户已保存配置继续恢复。修改后清旧生成结果、切换已保存上下文清输出、只配置选中首领及合包导入都需验证。

## 40专精爆发目录

独立源为data/burst-spells.json。先核对动作编号、专精、天赋替代证据与本地图片，再运行python tools/sync_spell_catalog.py；--check用于验证输出一致。统一入口同时验证40专精JS导出到真实Lua引擎以及名称／图标秘密值回退。生成文件不手工编辑；目录不保存默认冷却时间、不自动建立施法别名。详见research/BURST_CATALOG.md。
