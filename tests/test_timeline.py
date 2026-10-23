"""Website export -> actual Lua 5.1 parser, UI, preview and encounter scheduler."""
import json
import subprocess
import unittest
from check import runtime, ROOT


class TimelineTests(unittest.TestCase):
    def test_personal_heroic_without_tag_round_trips(self):
        result = subprocess.run(['node', '--input-type=module', '-e',
            "import {readFileSync} from 'node:fs'; import {parseNSRT,exportTimeline} from './web/timeline.mjs'; console.log(exportTimeline(parseNSRT(readFileSync('tests/fixtures/ulatek-heroic-personal.nsrt','utf8'))));"],
            cwd=ROOT,check=True,capture_output=True,text=True,encoding='utf-8')
        self.lua.globals().personal = result.stdout
        self.lua.execute('''
local p,err=NR.TimelinePlans.Parse(personal);assert(p,err)
assert(p.difficulty=='heroic' and #p.rows==18)
assert(p.rows[1].source.tag==nil and p.rows[1].source.time==3.9)
assert(p.rows[18].source.raw=='ph:1;time:569.9;spellid:1233448;')
NR.UI.note:SetText(personal);NR.UI:Parse();NR.UI:Save()
assert(#NR.TimelinePlans.Get(252,3492,'heroic').rows==18)
''')

    def setUp(self):
        result = subprocess.run(['node', str(ROOT/'tests/timeline_model.mjs')], cwd=ROOT,
                                check=True, capture_output=True, text=True, encoding='utf-8')
        self.fixture = json.loads(result.stdout)
        self.lua, self.nr = runtime(True)
        self.lua.globals().NR = self.nr
        self.lua.globals().note = self.fixture['text']
        self.lua.execute("created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')")

    def test_web_export_preserves_source_and_fractional_phases(self):
        self.lua.execute('''
local p,err=NR.TimelinePlans.Parse(note);assert(p,err)
assert(p.rows[1].offset==-10 and p.rows[1].fallback==135.5)
assert(p.rows[2].source.phase==1.5 and p.rows[3].source.phase==1.75 and p.rows[4].source.phase==2.5)
assert(p.rows[1].source.raw=='ph:1;time:135.5;tag:252;spellid:42650;')
assert(NR.BossRules.FindMechanic(3492,'mythic','heart').occurrences[1].at==145.5)
assert(NR.BossRules.FindMechanic(3492,'mythic','rage').occurrences[1].at==139)
''')

    def test_validation_rejects_corruption_unsupported_and_negative_signal(self):
        self.lua.execute('''
assert(not NR.TimelinePlans.Parse(note:gsub('Name:Ulatek','Name:%%XY')))
assert(not NR.TimelinePlans.Parse(note:gsub('fallback:135.5','fallback:broken')))
assert(not NR.TimelinePlans.Parse(note:gsub('sourcephase:1.5','sourcephase:broken')))
assert(not NR.TimelinePlans.Parse(note:gsub('timing:fixed','timing:signal')))
assert(not NR.TimelinePlans.Parse(note:gsub('RuleVersion:[^;]+','RuleVersion:old')))
assert(not NR.TimelinePlans.Parse(note:gsub('occurrence:1','occurrence:every')))
''')

    def test_real_ui_preview_save_and_isolated_rollback(self):
        self.lua.execute('''
NR.db.plans.keep={sentinel=42}
local ui=NR.UI;ui.note:SetText(note);ui:Parse();assert(ui.preview.kind=='timeline3')
ui:Save();assert(NR.db.lastPlanKind=='timeline3')
assert(NR.TimelinePlans.Get(252,3492,'mythic'))
ui:Play();assert(NR.preview.running and NR.preview.timelineMode)
NR.preview:Seek(135.5,0);assert(NR.preview.engine.rows[1].shown)
NR.preview:Seek(146,0);assert(NR.preview.engine.rows[1].done)
NR.preview:Stop()
local p=assert(NR.TimelinePlans.Parse(note));p.rows[1].fallback=140;assert(NR.TimelinePlans.Save(p))
assert(NR.TimelinePlans.Rollback(NR.db.lastTimelinePlan))
assert(NR.TimelinePlans.Get(252,3492,'mythic').rows[1].fallback==135.5)
assert(NR.db.plans.keep.sentinel==42)
ui.pausePlan.scripts.OnClick();assert(not NR.TimelinePlans.Get(252,3492,'mythic'))
''')

    def test_fixed_window_and_main_identity_matching(self):
        self.lua.execute('''
function GetSpecializationInfo() return 252 end
local p=assert(NR.TimelinePlans.Parse(note));p.rows[1].window=2;assert(NR.TimelinePlans.Save(p))
created[1].scripts.OnEvent(created[1],'ENCOUNTER_START',3492,'Ulatek',16,20)
assert(NR.engine.timelinePlan and #NR.engine.rows==4)
NR.engine:Tick(135.5);assert(NR.engine.rows[1].shown)
NR.engine:Tick(137.5);assert(NR.engine.rows[1].done)
NR.engine:Stop();function GetSpecializationInfo() return 251 end
created[1].scripts.OnEvent(created[1],'ENCOUNTER_START',3492,'Ulatek',16,20)
assert(not NR.engine.timelinePlan)
''')

    def test_stage_repeat_and_prediction_actual_correction(self):
        self.lua.execute('''
local p=assert(NR.TimelinePlans.Parse(note));p.rows={p.rows[1]}
local r=p.rows[1];r.anchor='stage:p2.5';r.occurrence='every';r.timing='signal';r.offset=1;r.fallback=nil
local e=NR.Engine.New();e:Begin(3492,'mythic',nil,{lead=0},0,{specID=252},nil,p)
e:Stage(2.5,100);assert(e.rows[1].target==101)
e:Stage(2.5,101);assert(e.rows[1].target==101)
e:Tick(120);assert(e.rows[1].done)
e:Stage(3,130);e:Stage(2.5,140);assert(e.rows[1].target==141 and not e.rows[1].done)
-- A synthetic prediction adapter tests scheduling only, not LIVE integration.
local m=NR.BossRules.FindMechanic(3492,'mythic','heart');m.prediction={enabled=true,kind='test'}
r.anchor='mechanic:heart';r.timing='predicted';r.occurrence=1;r.offset=-5
e:Begin(3492,'mythic',nil,{lead=0},0,{specID=252},nil,p)
e:MechanicEvent('heart',1,100,80,true,'same');assert(e.rows[1].target==95)
e:MechanicEvent('heart',1,102,90,false,'same');assert(e.rows[1].target==97)
e:Tick(97);assert(e.rows[1].shown)
e:Cast(42650,97);assert(e.rows[1].used)
e:MechanicEvent('heart',1,104,100,false,'same');assert(e.rows[1].target==97)
r.anchor='stage:p1';r.timing='signal';r.offset=2
e:Begin(3492,'mythic',nil,{lead=0},0,{specID=252},nil,p)
assert(e.rows[1].target==2)
''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
