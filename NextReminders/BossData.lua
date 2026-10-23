local _, NR = ...
-- Independently maintained data. Historical provenance is recorded in docs/RESEARCH.md.
-- Lorrgs phase numbers must be bound explicitly to these local anchors in the import preview.
NR.BossData = { schema = 1, dataVersion = "2026.10.23.2", encounters = {
    [3101] = { name = "密谋小径 老一", guard = 5,
        anchors = { [2] = "第一次转阶段（易伤预计再过 2 秒）", [3] = "第一次恢复正常阶段", [4] = "第二次转阶段", [5] = "第二次恢复正常阶段", [6] = "第三次转阶段" },
        rules = { { logicalPhase = 1, canceled = 2, nextLogicalPhase = 2 }, { logicalPhase = 2, added = 3, nextLogicalPhase = 1 } } },
    [3105] = { name = "密谋小径 老四", guard = 5, anchors = {}, rules = {},
        fixed = { { spellID = 474408, name = "放狗", times = {11.2,68.3,125.5,182.5,239.7,296.7} } },
        warning = "固定预报，打断时机会造成漂移" },
    [3457] = { name = "毒牙祭坛 老二", guard = 5,
        anchors = { [2] = "下一轮 1（Death Rattle 效果移除）", [3] = "下一轮 2", [4] = "下一轮 3", [5] = "下一轮 4" },
        rules = { { durations = {25,10} } }, warning = "该节点尚未与 EXBoss P2 做游戏实测对齐" },
    [2125] = { name = "塞塔里斯神庙 老二", guard = 5,
        anchors = { [2] = "下一轮 1（新增至少 5 个计时）", [3] = "下一轮 2", [4] = "下一轮 3", [5] = "下一轮 4" },
        rules = { { added = 5 } }, warning = "该节点尚未与 EXBoss 702 做游戏实测对齐" },
    [2127] = { name = "塞塔里斯神庙 老四", guard = 2,
        anchors = { [2] = "第一次进入 P2", [3] = "第一次返回 P1", [4] = "第二次进入 P2", [5] = "第二次返回 P1", [6] = "第三次进入 P2" },
        rules = { { durations = {15} }, { durations = {32.5} } } },
    [3208] = { name = "纳洛拉克洞穴 老二", guard = 5,
        anchors = { [2] = "下一轮 1", [3] = "下一轮 2", [4] = "下一轮 3", [5] = "下一轮 4", [6] = "下一轮 5" },
        rules = { { durations = {50,25,13,7} } } },
    [3492] = { name = "乌拉特克（心脏）", guard = 5, anchors = {}, rules = {},
        fixed = { { spellID = 1286860, name = "心脏（6.5 秒施法后，20 秒易伤）",
            timesHeroic = {129,278.1,567.2}, timesMythic = {139,288,583}, castDuration = 6.5, window = 20 } },
        warning = "WCL 与 BigWigs 已确认 P1→P2→P2.5→P3；旧 NSRT 若全为 ph:1，仍是开打相对方案" },
} }

-- Public signal candidates are independently maintained and difficulty-scoped.
-- Labels describe the intended mechanism; these mappings still require our own LIVE validation.
NR.BossData.encounters[3101].events={mythic={
    vuln={label="易伤生效",warning={severity=1},delay=1.7,guard=10,maxCount=4},
}}
NR.BossData.encounters[3105].events={mythic={
    dog={label="第一次放狗",bar={duration=10,batch={15,10,24}},guard=5,maxCount=1},
}}
NR.BossData.encounters[3457].events={mythic={
    p2={label="分体（待核对）",batch={10,25},guard=5,maxCount=10},
}}
NR.BossData.encounters[2125].events={mythic={
    snakes={label="召蛇（证据弱）",bar={duration=13,batch={13,36,5,25,44,49}},guard=5,maxCount=1},
}}

-- Lorrgs NSRT phase -> BigWigs stage (BigWigs_SetStage), any difficulty. Derived 2026-10-21 by reading the
-- Lorrgs backend phase rules and the BigWigs 12.1 modules; second offsets vs WCL and LIVE are still unverified.
-- match="value": Lorrgs phase P starts when BigWigs enters stage phases[P] (identity when phases is nil).
-- match="order": Lorrgs phase P starts at the (P-1)th BigWigs stage change after the pull.
NR.BossData.stages = {
    [3470] = { name = "Nek'zali", match = "value", phases = { [1.5] = 1.5, [2] = 2 },
        note = "P1.75（灵魂转移）BigWigs 没有对应阶段，请填时间" },
    [3445] = { name = "Entombed Sentinels", match = "value" },
    [3429] = { name = "The Coiled Altar", match = "value", phases = { [2] = 2, [2.5] = 2.5, [3] = 3 },
        note = "Lorrgs 把 P2.5／P3 起点各提前了 8／4 秒，与 BigWigs 的偏差待实测" },
    [3497] = { name = "The Lost Explorers", match = "order",
        note = "按 BigWigs 第几次切换对应，WCL 是否计入回到 P1 待核对" },
    [3492] = { name = "Ula'tek", match = "value", phases = { [2] = 2, [2.5] = 2.5, [3] = 3 },
        note = "WCL 阶段 ID 2/3/4 对应本地 P2/P2.5/P3；三份样本均跨区一致" },
    [3513] = { name = "Kith'ix", match = "value", phases = { [2] = 2 },
        note = "WCL 直接记录 P1→P2；三份样本的转阶段时间随击杀速度变化" },
}

NR.Stages = {}

function NR.Stages.Supports(encounterID, phase)
    local map = NR.BossData.stages[encounterID]
    if not map or not NR.Phase(phase) or phase <= 1 then return false end
    if map.match == "order" then return phase % 1 == 0 end
    if map.phases then return map.phases[phase] ~= nil end
    return true
end

-- Which Lorrgs phase begins at this BigWigs stage change (changes counts every change since the pull).
function NR.Stages.PhaseFor(map, stage, changes)
    if not map then return nil end
    if map.match == "order" then return changes + 1 end
    if not map.phases then return stage > 1 and stage or nil end
    for phase, mapped in pairs(map.phases) do if mapped == stage then return phase end end
end
