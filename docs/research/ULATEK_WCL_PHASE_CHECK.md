# 乌拉特克阶段核验（WCL 复核 2026-10-23）

## 结论

- 团本 8 号乌拉特克（WCL 名 Ula'tek，首领编号 3492）确有阶段：P1 → P2 → P2.5（中场）→ P3。
- WCL v2 读取的三份跨区史诗击杀都返回同一结构。WCL 阶段 ID 1／2／3／4 分别对应本地 P1／P2／P2.5／P3。
- 本机 BigWigs 的 `SetStage` 值为 1／2／2.5／3，与 WCL 的阶段结构一致。插件现已把 Lorrgs 的 `ph:2`、`ph:2.5`、`ph:3` 显式绑定到对应 BigWigs stage。
- 心脏读条与随后易伤是阶段内部的机制节点，不能把每次心脏易伤都算成一次大阶段切换。
- 用户此前感到“没有阶段”，根因是导入方案里 20 条提醒全部为 `ph:1`，并绑定开战。NSRT 没有携带阶段起点，插件不能凭空把这份全 P1 数据拆成 P2/P3。

## WCL 结果

三份史诗击杀的相对开打秒数如下：

| 报告 | fight | P1 | P2 | P2.5 | P3 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `2B8VzAK1JQjCDGHW` | 47 | 0.0 | 174.1 | 318.9 | 339.5 |
| `JYzPZDFa1xR6jtwm` | 7 | 0.0 | 174.1 | 319.0 | 372.6 |
| `kwdb1LfAgBx9NKq6` | 11 | 0.0 | 174.2 | 319.1 | 372.8 |

P2 和 P2.5 在三份记录中非常稳定；P3 从约 339.5 到 372.8 秒，随击杀速度和战术明显变化，不能写成固定秒数。游戏内应继续使用 BigWigs stage 作为实时锚点。

## 已接入规则

- P1：开战。
- P2：BigWigs stage 2。
- P2.5：BigWigs stage 2.5。
- P3：BigWigs stage 3。
- BigWigs 不可用、消息缺失或仍待实测时，用户可手填转阶段秒数作为兜底。

## 旧 NSRT 如何改

例如原始记录：

```text
EncounterID:3492;Difficulty:Mythic;Name:Ula'tek;
ph:1;time:180;tag:everyone;spellid:51271;
ph:1;time:325;tag:everyone;spellid:51271;
ph:1;time:350;tag:everyone;spellid:51271;
```

若选择上表第一份击杀作为边界：

```text
1=0, 2=174.1, 2.5=318.9, 3=339.5
```

则三行可转换为：

- `ph:2;time:5.9`
- `ph:2.5;time:6.1`
- `ph:3;time:10.5`

转换必须保留 `absoluteTime=180/325/350` 供校对。没有显式边界的全 P1 NSRT 只能继续按开打计时，网站兼容层应返回 `needs_phase_boundaries`，不能按平均时间猜。

## 历史记录

2026-10-22 曾实测 WCL 报告请求 504／超时，当时没有取得 `phaseTransitions`。这只是当时的服务状态，已被 2026-10-23 的后续查询取代。

## 证据边界

- 本次读取的是 WCL 公开报告、本机 BigWigs 源码/数据与插件规则，不是用户当前游戏内的实时战斗日志。
- WCL 和 BigWigs 的结构对齐已确认；`BigWigs_SetStage` 在实际战斗中何时发出，仍需用 `/nr log` 做 LIVE 核对。
- 没有读取或修改 NSRT 的 SavedVariables。
