# 实施方案：大秘境改用"首领事件"提醒（NextReminders 0.2.0）

日期 2026-10-12。Advisor（Claude）写方案，执行者（GPT）实现。对用户的文字一律写"副本 老N"，不写首领名。

**用户决定（2026-10-12）**：不用 EXBoss。用我们自己的计时条识别和事件识别，只需把每个首领"要等的事件"定义清楚。EXBoss 的数据只作为**对照参考**，用来核对计时条时长；运行时不读取、不订阅 EXBoss。

## 1. 为什么换做法

- 大秘境不能照搬团本"开打后 N 秒"的时间轴。高手的爆发等的是**首领事件**（易伤、分体、放狗），不是固定秒数。
- 2026-10-10～11 已用 CoolPlan 前 20 名记录统计出各专精"要等事件"的首领（第 5 节）。只有少数首领要等，而且只等第一次，其余首领好了就按。
- NextReminders 已经在监听暴雪的公开计时条（`ENCOUNTER_TIMELINE_EVENT_*`），并有按时长识别阶段的规则（`BossData.rules`、`Engine:Timeline`）。在这个基础上把"阶段"推广为"事件"即可。
- WCL 工具 `tools/wcl_note.mjs` 只留给团本用（第 7 节）。

## 2. 目标行为

在已有预设的首领战中，例如邪 DK 打密谋小径 老一：

1. 开打时，黑暗突变按"开打 + 0 秒"提醒。
2. 提示条常驻显示"亡者大军：留着，等易伤"（等待提示，可关）。
3. 识别到易伤预警时，在易伤生效前提前显示亡者大军和第二次黑暗突变，并倒数。
4. 用过技能后撤掉提醒，沿用现有 `engine:Cast`。
5. 只等第一次易伤；之后好了就按，不再提醒。

## 3. 事件定义（核心工作）

### 3.1 三种事件来源，全部只用公开数据

| 类型 | 识别方法 | 事件时刻 | 能否提前提醒 |
|---|---|---|---|
| `warning` | 自己注册 `ENCOUNTER_WARNING`，只读 `encounterWarningInfo.severity`，不碰其他字段（其他字段可能是 secret） | 收到时刻 + `delay` | 能，最多提前 `delay` 秒 |
| `bar` | 计时条新增时，按时长（±0.1 秒）认出是哪条；可要求它和其他几条同一批出现（0.3 秒内，即 `batch`） | 这条计时条结束：预计为新增时刻 + 时长；状态变为 Finished 时按实际时刻校正；被 Canceled 则撤回 | 能，从计时条出现起就知道 |
| `batch` | 一批新增计时条的时长集合匹配（现有 `MatchesDurations`），即现在的"转阶段"规则 | 识别时刻 | 不能，发生时才知道 |

另有 `start`（ENCOUNTER_START）作为固定事件。

### 3.2 四个首领的事件（数据写进 `BossData.lua`）

计时条时长取自 EXBoss 的 `EXBossData/FixedTimelineBosses.lua`，只作参考。其中只有老一易伤和老四放狗经过游戏实测（TMN 2026-10-10～11）。

```lua
[3101] = { events = {   -- 密谋小径 老一
    vuln = { label = "易伤生效", warning = { severity = 1 }, delay = 1.7, maxCount = 4 } } },
    -- 实测：易伤没有对应技能，计时条在易伤期间清空；唯一信号是 ENCOUNTER_WARNING severity==1。
    -- delay 1.7 与 EXBoss ShowVulnerability(100, 1.7, 20) 一致，易伤持续 20 秒。
[3105] = { events = {   -- 密谋小径 老四
    dog = { label = "放狗", bar = { duration = 10, batch = {15, 10, 24} } } } },
    -- 开打同批出现 15/10/24 秒三条，10 秒那条结束 = 第一次放狗（实测准确）。
    -- 之后的放狗是单独一条 57 秒的计时条；预设只等第一次，所以本版不需要。
[3457] = { events = {   -- 毒牙祭坛 老二
    p2 = { label = "分体", batch = {10, 25} } } },
    -- 与现有 rules {durations={25,10}} 是同一个识别；未实测。
[2125] = { events = {   -- 塞塔里斯神庙 老二
    snakes = { label = "召蛇", bar = { duration = 13, batch = {13, 36, 5, 25, 44, 49} } } } },
    -- 开打同批 6 条，13 秒那条结束 = 召蛇；未实测，证据弱。
```

字段校验和现有 BossData 合同检查一样严格：每个事件恰好一种来源，时长为正数，`batch` 包含 `duration`。

### 3.3 与现有阶段规则的关系

- 密谋小径 老一现有的阶段规则是"取消 2 条计时条 → 转阶段，猜测易伤约 2 秒后生效"，这是猜测。本版事件改用 `ENCOUNTER_WARNING`，现有阶段规则不动，留给导入方案的阶段绑定使用。等 LIVE 证明两者一致后，再考虑统一。
- 毒牙祭坛 老二的 `p2` 与现有规则是同一种识别。实现时让两者共用 `MatchesDurations` 的结果，避免同一批计时条被判断两次、结果不同。
- 其他首领只加 `events`，不改 `anchors/rules`。`dataVersion` 递增。

### 3.4 Main.lua 需要的改动

- 注册 `ENCOUNTER_WARNING`。处理函数只取 `severity`：先用 `NR.Public` 判断，不是公开值就丢弃。
- `ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED`：现在只转发 Canceled，改为同时转发 Finished，供 `bar` 事件按实际结束时刻校正。暂停（Paused）期间，预计时刻顺延，或者等 Finished 再定；选一种做法，写进测试。
- 新增：`ENCOUNTER_START` 之前就已存在的计时条只记录来源，不参与识别（沿用 `snapshot` 规则）。

## 4. 引擎与数据

### 4.1 引擎：事件锚点

`Engine.lua` 已有 `anchorTimes`（`pull` 和阶段序号）。扩展如下：

- 行字段：`anchor`（事件键：`"start"` 或 BossData 中的事件名，如 `"vuln"`、`"dog"`）；`occurrence`（第几次，默认 1）或 `every = true`；`time`（事件后秒数）；`hold`（可选，等待提示文字）。
- `engine:BossEvent(key, eventTime, count, predicted)`：对满足 `occurrence == count` 或 `every` 的行，设置 `row.target = eventTime + row.time`。`predicted = true` 表示时刻是预计的，之后收到实际时刻要更新 `target`，被撤回就隐藏这一行并允许下次重新触发。`every` 行每次发生时重置。显示、倒数、到期都沿用现有 `Tick`。
- 提前量：`target - lead` 早于识别时刻时，识别到就显示，倒数照常。界面上注明 `batch` 类事件没有提前量。
- 等待提示：`Begin` 时把带 `hold` 的行以 `emit("hold", row)` 显示为静态条（不倒数、不发声）。锚点事件识别到后撤掉、转为正常提醒；首领战结束清掉。
- 事件行的加载条件：当前专精有预设，`encounterID` 匹配，难度为 mythic（含钥石）。与时间轴方案并存：`Begin` 先放时间轴行，再追加事件行。
- `/nr log` 的记录中加入事件识别（键、次数、预计/实际时刻），方便 LIVE 核对。

### 4.2 专精预设 `NextReminders/SpecPresets.lua`

```lua
NR.SpecPresets = { schema = 1, dataVersion = "2026.10.12.1", specs = {
  [252] = { name = "邪恶死亡骑士", source = "CoolPlan 前 20 · 2026-10-11", encounters = {
    [3101] = { rows = {
      { spellID = 42650,   anchor = "vuln",  occurrence = 1, time = 0, hold = "亡者大军：留着，等易伤" },
      { spellID = 1233448, anchor = "start", time = 0 },
      { spellID = 1233448, anchor = "vuln",  occurrence = 1, time = 0 },
    } },
  } },
} }
```

校验：`anchor` 必须是 `start` 或该首领 `events` 中存在的键；`time` 在 0～600 之间，最多一位小数；spellID 为正整数。

### 4.3 存档

`NextRemindersDB.eventPlans[specID][encounterID] = { enabled = true, rows = {...} }`。首次使用时从预设复制，之后用户改动只改存档。预设 `dataVersion` 变化时，只在界面上提示"有新的推荐"，不自动覆盖。

### 4.4 界面

新增第三个分页"大秘境"（现有分页是"方案导入"和"提醒设置"）：

- 顶部：当前专精。
- 列表：每个有预设的首领一块，标题为"副本 老N"。副本中文名和首领顺序写进我们自己的 BossData（新增 `dungeon`、`order` 字段），不读 EXBoss。每行是"技能图标 · 事件 · 第几次 · 事件后 N 秒 · 等待提示"，带启用勾选。证据弱的行默认不勾，并标注"证据弱"。
- "添加一行"：首领下拉 → 事件下拉（开打 + 这个首领 `events` 里的事件）→ 第一次 / 每次 → 秒数 → 技能 ID。
- "恢复推荐"：用预设覆盖这个首领的存档，需要确认。战斗中拒绝修改。

预览窗口：事件行增加"触发：易伤生效 / 分体 / 放狗 / 召蛇"按钮，做法同现有的"进入：阶段"手动按钮。`warning` 和 `bar` 类事件按其提前量演练，以便看到提前显示和倒数。

## 5. 预设内容（来自已有统计）

依据：邪 DK 见 `C:\Users\leslie\Downloads\General\WoW\邪DK-大秘境需要注意的首领.md`；冰 DK 见 TellMeNext 会话 2026-10-11 的结论，摘要在 TMN `docs/PROJECT_STATE.md` 2.28 节。两份都是 CoolPlan 前 20 名记录，并经 Advisor 复算。

**邪 DK（252）**：大爆发是亡者大军 42650，小爆发是黑暗突变 1233448。

| 首领 | 行 |
|---|---|
| 密谋小径 老一（3101） | 大军 · vuln · 第 1 次 · +0 · 等待提示；突变 · start · +0；突变 · vuln · 第 1 次 · +0 |
| 毒牙祭坛 老二（3457） | 大军 · p2 · 第 1 次 · +0 · 等待提示；突变 · start · +0；突变 · p2 · 第 1 次 · +0 |

**冰 DK（251）**：冰柱 51271；辛达苟萨之息 1249658。

| 首领 | 行 | 证据 |
|---|---|---|
| 密谋小径 老一（3101） | 冰柱 · start · +0；冰柱 · vuln · 第 1 次 · +3 · 等待提示；吐息 · vuln · 第 1 次 · +3 · 等待提示 | 强；易伤时刻已实测 |
| 密谋小径 老四（3105） | 冰柱、吐息 · dog · 第 1 次 · +0 | 中；放狗时刻已实测 |
| 毒牙祭坛 老二（3457） | 吐息 · p2 · 第 1 次 · +0 | 强（18/20）；分体未实测 |
| 塞塔里斯神庙 老二（2125） | 吐息 · snakes · 第 1 次 · +3，默认不勾 | 弱（21/32） |

执行者需核对：

1. 冰 DK 记录里"冰龙"（279302）和"吐息"（1249658）的用词前后不一致。预设按最终配置只放吐息，在交付报告里列出这一点，由用户决定。
2. 毒牙祭坛 老二分体的备选：开打同批中 44 秒那条计时条结束后 +7 秒（"濒死喘息"）。在预设里以注释形式保留，不作为默认。
3. 黑暗突变 1233448、辛达苟萨之息 1249658 是 12.0 的新 ID，交付前核对一次。

## 6. TellMeNext 改名（单独的小任务）

用户要求把 TMN 的"EXBoss 首领事件"条件改叫"首领"。只改显示文字（`displayName`、摘要前缀、Locale、`MODULAR_CONDITIONS.md`），**不改条件 id `exboss_event`**，旧存档不用迁移。按 TellMeNext 的 `AGENTS.md` 在 `.local/` 下建独立工作树，跑统一入口；未经授权不提交。TMN 这个条件内部是否也改用自有识别，不在本次范围。

## 7. WCL 工具的定位

`tools/wcl_note.mjs` 去掉 `--dungeon` 用法，遇到大秘境报告时提示"大秘境请用首领事件预设"。README 的 WCL 一节只写团本用法。

## 8. 文件范围与禁止事项

可改：`NextReminders/` 下的 `BossData.lua`、`SpecPresets.lua`（新）、`Engine.lua`、`Main.lua`、`Display.lua`、`Preview.lua`、`PreviewUI.lua`、`UI.lua`、`Core.lua`、`NextReminders.toc`；`tests/check.py`、`tools/wcl_note.mjs`、`README.md`、`docs/*`。

禁止：

- 运行时读取、订阅或依赖 EXBoss / ExwindTools，TOC 不加依赖。
- 读取 `encounterWarningInfo` 中 `severity` 以外的字段。
- 在 Lua 里比较或分支 secret 值。
- 自动覆盖用户已改过的事件方案。
- 不经用户同意安装到游戏目录，或提交、发布。

## 9. 验收用例（MOCK，加进 `tests/check.py`）

1. `warning`：3101 中 severity 1 → 事件时刻为收到时刻 + 1.7；severity 0/2、secret 值、非 3101 首领都不触发；超过 `maxCount` 不再计数。
2. `bar`：3105 开打同批新增 15/10/24 → `dog` 预计在新增后 10 秒；Finished 提前或推后时按实际时刻校正；Canceled 时撤回；只出现一条 10 秒计时条（不成批）时不触发；开打前已存在的计时条不参与识别。
3. `batch`：3457 同批 10/25 → `p2` 在识别时刻触发；与现有阶段规则同时存在时结果一致，只识别一次。
4. 引擎：邪 DK 打 3101。开打后突变立即显示；大军等待提示出现；易伤预警后大军和突变提前显示，并倒数到生效时刻；第二次易伤不再提醒；施放 42650 后撤掉；ENCOUNTER_END 后全部清掉。
5. `every = true` 的行在第二次事件时重新提醒；`occurrence = 2` 的行只在第二次触发。
6. 在非预设首领、非 mythic 难度、或换成别的专精时，不加载事件行；时间轴方案照常工作。
7. 界面：分页、"副本 老N"标题、添加行、改秒数、取消勾选后保存、恢复推荐需要确认、战斗中拒绝修改、预设版本更新时只提示。
8. 预览：点"触发：易伤生效"后提前显示、倒数；后退后能重新演练。
9. BossData 合同检查覆盖 `events`；现有 22 项测试全部通过；`python tools/build.py` 成功。

## 10. LIVE 验收顺序（交付后给用户）

每只首领打完后复制 `/nr log`，核对事件识别时刻。

1. 密谋小径 老一：等待提示 → 易伤前约 1.7 秒出提醒，倒数到易伤生效 → 用技能后撤掉 → 第二次易伤不再提醒。
2. 密谋小径 老四（冰 DK）：放狗前出提醒，在放狗时刻倒数到"现在"。
3. 毒牙祭坛 老二：首领分体时出提醒。这一项首次 LIVE 验证，如果不准，改用备选。
4. 塞塔里斯神庙 老二：勾选后看召蛇时刻。
5. 其他首领：没有任何事件提醒。

## 11. 停止点

MOCK 全部通过、构建产物生成后停止。交付时说明：改动文件列表；测试数量；第 5 节三项核对的结果；暂停状态采用了哪种做法；未做的项。状态写 `source_review=PENDING`、`LIVE=NOT_RUN`，等 Advisor 验收。
