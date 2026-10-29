"""Generate browser and Lua boss rule modules from data/boss-rules.json."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data" / "boss-rules.json"
JS_OUTPUT = ROOT / "tests" / "fixtures" / "protocol" / "boss-rules.mjs"
LUA_OUTPUT = ROOT / "NextReminders" / "BossRules.lua"
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while",
}


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def lua_value(value, indent: int = 0) -> str:
    pad = "    " * indent
    child = "    " * (indent + 1)
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (int, float)):
        return json.dumps(value)
    if isinstance(value, list):
        if not value:
            return "{}"
        lines = ["{"]
        lines.extend(f"{child}{lua_value(item, indent + 1)}," for item in value)
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = ["{"]
        for key, item in value.items():
            valid_identifier = re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key)
            rendered_key = (
                key
                if valid_identifier and key not in LUA_KEYWORDS
                else f"[{lua_string(key)}]"
            )
            lines.append(f"{child}{rendered_key} = {lua_value(item, indent + 1)},")
        lines.append(f"{pad}}}")
        return "\n".join(lines)
    raise TypeError(f"Unsupported JSON value: {type(value).__name__}")


LUA_HELPERS = r'''

local B = NR.BossRules

function B.For(encounterID, difficulty)
    local id = tostring(encounterID)
    local encounter = B.encounters[id]
    if not encounter or type(encounter.difficulties) ~= "table" then return nil end
    return encounter, encounter.difficulties[difficulty]
end

function B.FindStage(encounterID, difficulty, stageID)
    local _, rules = B.For(encounterID, difficulty)
    if not rules or type(rules.stages) ~= "table" then return nil end
    for _, stage in ipairs(rules.stages) do
        if tostring(stage.id) == tostring(stageID) then return stage end
    end
end

function B.FindMechanic(encounterID, difficulty, mechanicID)
    local _, rules = B.For(encounterID, difficulty)
    if not rules or type(rules.mechanics) ~= "table" then return nil end
    for _, mechanic in ipairs(rules.mechanics) do
        if tostring(mechanic.id) == tostring(mechanicID) then return mechanic end
    end
end

function B.Occurrence(mechanic, index)
    if type(mechanic) ~= "table" or type(mechanic.occurrences) ~= "table" then return nil end
    for _, occurrence in ipairs(mechanic.occurrences) do
        if occurrence.index == index then return occurrence end
    end
end

function B.ParseAnchor(anchor)
    if anchor == "start" then return "start" end
    if type(anchor) ~= "string" then return nil end
    local stage = anchor:match("^stage:(.+)$")
    if stage then return "stage", stage end
    local mechanic = anchor:match("^mechanic:(.+)$")
    if mechanic then return "mechanic", mechanic end
end

function B.ValidateAnchor(encounterID, difficulty, anchor)
    local kind, id = B.ParseAnchor(anchor)
    if kind == "start" then return true end
    if kind == "stage" then return B.FindStage(encounterID, difficulty, id) ~= nil end
    if kind == "mechanic" then return B.FindMechanic(encounterID, difficulty, id) ~= nil end
    return false
end

function B.SignalSupported(encounterID, difficulty, mechanicID)
    local mechanic = B.FindMechanic(encounterID, difficulty, mechanicID)
    local signal = mechanic and mechanic.signal
    return type(signal) == "table" and signal.enabled == true and signal.kind ~= "none"
end

function B.PredictionSupported(encounterID, difficulty, mechanicID)
    local mechanic = B.FindMechanic(encounterID, difficulty, mechanicID)
    local prediction = mechanic and mechanic.prediction
    return type(prediction) == "table" and prediction.enabled == true and prediction.kind ~= "none"
end

function B.FixedTime(encounterID, difficulty, mechanicID, occurrenceIndex)
    local mechanic = B.FindMechanic(encounterID, difficulty, mechanicID)
    local occurrence = mechanic and B.Occurrence(mechanic, occurrenceIndex)
    return occurrence and occurrence.at or nil
end

function B.AnchorLabel(encounterID, difficulty, anchor)
    local kind, id = B.ParseAnchor(anchor)
    if kind == "start" then return "开战" end
    if kind == "stage" then
        local stage = B.FindStage(encounterID, difficulty, id)
        return stage and stage.label or ("阶段 " .. tostring(id))
    end
    if kind == "mechanic" then
        local mechanic = B.FindMechanic(encounterID, difficulty, id)
        return mechanic and mechanic.label or ("机制 " .. tostring(id))
    end
    return "未绑定"
end

function B.BigWigsStageID(encounterID, difficulty, stage)
    local _, rules = B.For(encounterID, difficulty)
    if not rules or type(rules.stages) ~= "table" or not NR.Phase(stage) then return nil end
    for _, candidate in ipairs(rules.stages) do
        local signal = candidate.signal
        if type(signal) == "table" and signal.kind == "bigwigs" and signal.enabled == true then
            if signal.value == stage and signal.value ~= nil then return candidate.id end
            if signal.value == nil and NR.Number(signal.from, 1, 100) and stage >= signal.from then
                return candidate.id
            end
        end
    end
end
'''


def render_lua(data: dict) -> str:
    return (
        "-- Generated by tools/sync_boss_rules.py from data/boss-rules.json. Do not edit by hand.\n"
        "local _, NR = ...\n"
        f"NR.BossRules = {lua_value(data)}\n"
        f"{LUA_HELPERS.lstrip()}"
    )


def render_js(data: dict) -> str:
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    return (
        "// Generated by tools/sync_boss_rules.py from boss-rules.json. Do not edit by hand.\n"
        f"export const BOSS_RULES = {payload};\n"
        "export const RULE_ENCOUNTERS = Object.entries(BOSS_RULES.encounters).map(([id, encounter]) => ({\n"
        "  id: Number(id),\n"
        "  ...encounter,\n"
        "}));\n"
    )


def build_outputs() -> dict[Path, str]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or not isinstance(data.get("encounters"), dict):
        raise ValueError("boss-rules.json schema must be 1 with an encounters object")
    return {
        JS_OUTPUT: render_js(data),
        LUA_OUTPUT: render_lua(data),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs = build_outputs()
    stale = []
    for path, content in outputs.items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != content:
            stale.append(path.relative_to(ROOT).as_posix())
            if not args.check:
                path.write_text(content, encoding="utf-8", newline="\n")
    if args.check and stale:
        print("Boss rule outputs are stale: " + ", ".join(stale))
        return 1
    print("Boss rule outputs are current." if args.check else "Boss rule outputs generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
