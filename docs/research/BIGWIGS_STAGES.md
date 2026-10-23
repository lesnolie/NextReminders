# Lorrgs 阶段 ↔ BigWigs 阶段

整理日期 2026-10-21，WCL 复核 2026-10-23。来源：Lorrgs 后端各首领阶段规则（GitHub gitarrg）、本机 BigWigs 12.1 模块源码、Warcraft Logs v2 公开报告、梦工坊 BossDetect 仅作线索。数据在 `NextReminders/BossData.lua` 的 `NR.BossData.stages`，按自维护规则对待，游戏内消息仍需 LIVE 核对。

2026-10-23 复核更新：WCL v2 已恢复可用。对 28 只大秘境首领和 10 只团本首领各读取 3 份跨区击杀；团本有 7 只取得 `phaseTransitions`，大秘境该字段为空或缺失，因此改用阶段专属施法、客户端事件与血量规则交叉判断。乌拉特克三份击杀均确认 P1→P2→P2.5→P3，现已映射 BigWigs stage 2／2.5／3；Kith'ix 的三份击杀均确认 P1→P2，并映射 stage 2。完整结果见 [WCL 全首领阶段审计](WCL_PHASE_AUDIT.md)。

2026-10-22 的 WCL 504／超时是当时的一次实测记录，已被 10-23 的后续结果取代；原用户英雄方案 20 条全为 `ph:1`，它仍不会自动变成阶段相对方案。

## 机制

- Lorrgs NSRT `ph:X;time:S` 的 S 是相对来源战斗中该阶段开始的秒数；静态首领一律 `ph:1` 开打相对。
- BigWigs 在 `boss:SetStage` 发 `BigWigs_SetStage(module, stage)`（stage>0 且已开战），engage 时 `SetStage(1)`；公开订阅 `BigWigsLoader.RegisterMessage(owner, msg, fn)`（点号调用）。
- value：来源阶段 P 在 BigWigs 进入 phases[P] 时开始（无 phases 时同值）。order：第 N 次 BigWigs 阶段切换开始来源 P(N+1)。

## 当前团本十只首领

| 首领 | Lorrgs | BigWigs | 本插件 |
|---|---|---|---|
| 3470 奈克扎利 | 1.5 首次觉醒仪式；1.75 首次灵魂转移读条；2 解缠 | 1→1.5（首次通道）→2（第二次通道） | 1.5、2 自动；1.75 必须填时间 |
| 3445 墓葬哨兵 | WCL 转阶段顺序编号 2,3,4… | 中场后首个计时事件 stage+1 | 三份 WCL 均 P1／P2 往返；LIVE 待核对 |
| 3429 盘绕祭坛 | 2；2.5＝WCL P3 −8 秒；3＝WCL P4 −4 秒 | 2；2.5（StartIntermission）；3（灵魂束缚通道停止） | WCL 三份均 P1→P2→P2.5→P3；秒数随 DPS 变化 |
| 3497 失落探险者 | 每次 WCL 转阶段顺序 2,3,4,5 | 阶段值是被强化的探险者，回 1 也算 | WCL 临时 ID 2／3／4 不固定，只能按切换顺序 |
| 3420 Sszorak | WCL P1↔P2 | 没有 `SetStage` | WCL 稳定确认往返，但插件不做 BigWigs 自动绑定 |
| 3492 乌拉特克 | P1、P2、P2.5、P3 | stage 2、2.5、3 | WCL + BigWigs 结构对齐；P2／P2.5 很稳定，P3 随击杀变化 |
| 3513 Kith'ix | P1、P2 | stage 2 | 三份 WCL 均只发生一次 P1→P2；具体机制待 LIVE |
| 3455 Vashnik、3421 双牙、3379 Nymrissa | WCL 无阶段字段 | 无 `SetStage` 或阶段证据不足 | 仅按普通事件处理 |

## 待办

1. 游戏内用 `/nr` 跟踪日志（stage／stage-source）实测 3470、3429、3492、3513 的 BigWigs 消息与 WCL phase ID 对照；需要时给 stages 增加 offset 字段。
2. 3497 用 LIVE 核对回到 P1 是否计入 Lorrgs 编号。
3. 3470 的 P1.75 没有独立 BigWigs stage，继续要求用户填写触发后的秒数。
