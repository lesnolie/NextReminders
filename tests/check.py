from pathlib import Path
import argparse
import json
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "NextReminders"

MOCK = r'''
now = 0
combat = false
messages = {}
function GetTime() return now end
function time() return 1 end
function issecretvalue(v) return type(v)=="table" and rawget(v,"secret")==true end
function InCombatLockdown() return combat end
function UnitName(u) return "Leslie", "Realm" end
function UnitClass() return "Death Knight", "DEATHKNIGHT" end
function UnitGroupRolesAssigned() return "DAMAGER" end
function IsInRaid() return false end
function UnitIsUnit(a,b) return a==b end
function GetSpecialization() return 2 end
function GetSpecializationInfo() return 251 end
DEFAULT_CHAT_FRAME = {AddMessage=function(_,s) messages[#messages+1]=s end}
SlashCmdList={}; UISpecialFrames={}; GameFontHighlight={}; SOUNDKIT={RAID_WARNING=1}
function PlaySound() end
local focusedEditor
function object()
 local t={scripts={}, shown=false, text="", checked=false}
 return setmetatable(t,{__index=function(self,k)
  if k=="CreateTexture" then return function() local o=object(); o.owner=self; return o end end
  if k=="CreateFontString" then return function() local o=object(); o.owner=self; fontStrings[#fontStrings+1]=o; return o end end
  if k=="SetScript" then return function(_,key,f) self.scripts[key]=f end end
  if k=="HookScript" then return function(_,key,f)
   local old=self.scripts[key]
   self.scripts[key]=function(...) if old then old(...) end; f(...) end
  end end
  if k=="SetText" then return function(_,v) self.text=v end end
  if k=="GetText" then return function() return self.text end end
  if k=="SetChecked" then return function(_,v) self.checked=v end end
  if k=="GetChecked" then return function() return self.checked end end
  if k=="Show" then return function() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
  if k=="Hide" then return function() local wasShown=self.shown; self.shown=false; if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end end end
  if k=="IsShown" then return function() return self.shown end end
  if k=="IsVisible" then return function() return self.shown end end
  if k=="IsForbidden" then return function() return false end end
  if k=="GetHeight" then return function() return rawget(self,"height") or 900 end end
  if k=="GetWidth" then return function() return rawget(self,"width") or 1440 end end
  if k=="SetSize" then return function(_,w,h) self.width=w; self.height=h end end
  if k=="SetWidth" then return function(_,w) self.width=w end end
  if k=="SetHeight" then return function(_,h) self.height=h end end
  if k=="SetJustifyH" then return function(_,v) self.justifyH=v end end
  if k=="SetJustifyV" then return function(_,v) self.justifyV=v end end
  if k=="SetBlinkSpeed" then return function(_,v) self.blinkSpeed=v end end
  if k=="SetPoint" then return function(_,...) self.point={...} end end
  if k=="EnableMouse" then return function(_,v) self.mouseEnabled=v end end
  if k=="SetTextInsets" then return function(_,...) self.textInsets={...} end end
  if k=="SetAutoFocus" then return function(_,v) self.autoFocus=v end end
  if k=="GetFrameLevel" then return function() return rawget(self,"frameLevel") or (rawget(self,"parent") and self.parent:GetFrameLevel()+1) or 0 end end
  if k=="SetFrameLevel" then return function(_,v) self.frameLevel=v end end
  if k=="HasFocus" then return function() return rawget(self,"focused")==true end end
  if k=="SetFocus" then return function()
   if focusedEditor==self then return end
   if focusedEditor then focusedEditor:ClearFocus() end
   focusedEditor=self;self.focused=true
   if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
  end end
  if k=="ClearFocus" then return function()
   if not rawget(self,"focused") then return end
   self.focused=false;if focusedEditor==self then focusedEditor=nil end
   if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
  end end
  if k=="GetVerticalScroll" then return function() return rawget(self,"verticalScroll") or 0 end end
  if k=="SetVerticalScroll" then return function(_,v) self.verticalScroll=v end end
  if k=="SetBackdropColor" then return function(_,...) self.backdropColor={...} end end
  if k=="SetBackdropBorderColor" then return function(_,...) self.backdropBorderColor={...} end end
  if k=="SetEnabled" then return function(_,v) self.enabled=v end end
  if k=="SetAlpha" then return function(_,v) self.alpha=v end end
  if k=="unit" or k=="displayedUnit" then return nil end
  return function() end
 end})
end
UIParent=object()
created={}
fontStrings={}
function CreateFrame(_,name,parent,template)
 local t=object(); created[#created+1]=t; t.parent=parent; t.template=template
 if name then _G[name]=t end
 return t
end
C_Spell={GetSpellInfo=function(id) return {name="Spell "..id,iconID=id} end,
 GetSpellCooldown=function() return {isEnabled=true,isActive=false,isOnGCD=false} end}
-- Text-to-speech was removed; the mock stays so tests can assert it is never called.
voiceCalls={}
C_VoiceChat={GetTtsVoices=function() return {{voiceID=1}} end,
 SpeakText=function(_,text) voiceCalls[#voiceCalls+1]=text end}
soundCalls={}
PlaySoundFile=function(path) soundCalls[#soundCalls+1]=path; return true end
Enum={EncounterTimelineEventState={Active=0,Paused=1,Finished=2,Canceled=3}}
C_EncounterTimeline={GetEventState=function() return 3 end}
'''


def runtime(all_files=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    nr = lua.table()
    names = ["Core.lua", "SpellCatalog.lua", "BurstSpells.lua", "Theme.lua", "BossRules.lua", "BossData.lua", "DungeonData.lua", "Import.lua", "EventPlans.lua", "TimelinePlans.lua", "BossEvents.lua", "Ready.lua", "Engine.lua", "Preview.lua"]
    if all_files: names += ["Sounds.lua", "Display.lua", "PreviewUI.lua", "UI.lua", "BurstUI.lua", "Main.lua"]
    for name in names:
        chunk = lua.execute("return assert(loadstring(...))",(ADDON/name).read_text(encoding="utf-8"))
        chunk("NextReminders",nr)
    return lua, nr


class PluginTests(unittest.TestCase):

    def test_reference_event_replay_matches_export_and_manual_rows_reorder(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local plan=NR.EventPlans.New(252,3101)
plan.rows={}
for i,at in ipairs({4.5,91,140.6,186.4,0,186.1}) do
 plan.rows[i]={id=i,spellID=i>=5 and 42650 or 63560,anchor=i==5 and 'vuln' or 'start',occurrence=1,time=at,window=10}
end
local ui=NR.PreviewUI
assert(ui:Open(plan))
local p=NR.preview
assert(p.expected['event:5']==91.5 and p.duration==202)
assert(ui.order[3]==5 and #p.chapters==2 and p.chapters[2].estimated)
p:Tick(92);assert(p.engine.rows[5].used and p.engine.rows[5].target==91.5)
p:Seek(0,92);assert(not p.engine.rows[5].target)
p:Seek(92,92);assert(p.engine.rows[5].used)
assert(plan.rows[5].time==0 and not plan.rows[5].used and plan.rows[3].time==140.6)
assert(p:SetReferenceEvents(false,92));p:Seek(10,92)
assert(p:Event('vuln',92));ui.lastUpdate=nil;ui:Update()
assert(p.engine.rows[5].target==11.7 and ui.order[2]==5,'manual events must reorder by actual target')
p:Seek(0,92);ui.lastUpdate=nil;ui:Update()
assert(ui.order[6]==5,'rewinding before the manual event restores unknown ordering')
plan.rows[5].occurrence=2
ui.referenceEvents=true;assert(ui:Open(plan))
assert(not p.expected['event:5'],'do not invent a second vulnerability time')
p:Seek(200,0);assert(not p.engine.rows[5].target)
local e=NR.Engine.New();e:Begin(3101,'mythic',nil,{},0,{specID=252},plan)
e:Tick(200);assert(not e.rows[5].target,'preview estimates must never trigger live reminders')
''')

    def test_littlewigs_warning_bridge_filters_and_deduplicates_native_signal(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
function GetSpecializationInfo() return 252 end
local handlers={}
BigWigsLoader={RegisterMessage=function(owner,message,fn) handlers[message]=fn end}
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
assert(NR.EventPlans.Save(NR.EventPlans.New(252,3101)))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8)
local f=assert(handlers.BigWigs_Message)
local module={GetEncounterID=function()return 3101 end}
local events=NR.engine.bossEvents
now=10
f(nil,{GetEncounterID=function()return 3105 end},1230304)
f(nil,module,999);f(nil,module,{secret=true})
assert(not events.counts.vuln)
f(nil,module,1230304)
assert(events.counts.vuln==1 and events.records.vuln.at==11.7)
driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',{severity=1})
assert(events.counts.vuln==1)
now=30;driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',{severity=1})
f(nil,module,1230304)
assert(events.counts.vuln==2 and events.records.vuln.at==31.7)
driver.scripts.OnEvent(driver,'ENCOUNTER_END');now=50;f(nil,module,1230304)
assert(events.counts.vuln==2)
''')

    def test_import_editor_is_above_its_background_and_errors_remain_visible(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI;local editor,scroll=ui.note,ui.note.parent
assert(scroll:GetFrameLevel()>ui.notePanel:GetFrameLevel(),'scroll viewport must be above the input background')
assert(editor:GetFrameLevel()>scroll:GetFrameLevel(),'text and caret must be above the viewport')
assert(scroll.parent==ui.notePanel,'input must inherit the card visibility and layering')
assert(editor.point[1]=='TOPLEFT' and editor.point[2]==scroll,'scroll child must have an explicit origin')
ui.notePanel.scripts.OnMouseDown(ui.notePanel,'LeftButton')
assert(editor:HasFocus() and ui.noteCaret:IsShown())
ui:Parse()
assert(not ui.preview and ui.summary:GetText()~='','empty input must explain the failure in the check panel')
editor:SetText('EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;')
editor.scripts.OnTextChanged(editor);ui:Parse()
assert(ui.preview and ui.summary:GetText()~='')
''')

    def test_saved_library_lists_paused_plans_selects_and_rehearses_without_mutation(self):
        lua,nr=runtime(True);lua.globals().NR=nr;lua.globals().note=self.dungeon_note()
        lua.execute(r"""
function GetSpecializationInfo() return 252 end
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
local ui=NR.PreviewUI
assert(ui:OpenLibrary());assert(#ui.entries==0 and not ui.play.themeEnabled)
NR.UI.note:SetText(note);NR.UI:Parse();NR.UI:Save()
local saved=NR.EventPlans.Find(252,3105,'mythic');saved.enabled=false
local static=assert(NR.ParseNote('EncounterID:3492;Difficulty:Heroic;Name:Raid;\nph:1;time:20;spellid:51271;'))
NR.NotePlans(251).plans['3492:heroic']=static
assert(ui:OpenLibrary());assert(#ui.entries==2,'other spec is not listed')
local index
for i,e in ipairs(ui.entries) do if e.plan.encounterID==3105 then index=i end end
assert(index);ui.entryButtons[index].scripts.OnClick()
assert(ui.detail:GetText():find('已暂停'))
assert(NR.preview.running and not NR.preview.playing,'inspection loads paused')
ui.play.scripts.OnClick();assert(NR.preview.playing)
NR.preview:Event('dog',0);NR.preview:Seek(12,0)
assert(saved.enabled==false and saved.rows[1].time==0)
ui.frame:Hide();combat=true
assert(not ui:OpenLibrary() and not NR.preview.running)
combat=false;function GetSpecializationInfo() return 251 end
ui:OpenLibrary();assert(#ui.entries==1 and ui.entries[1].plan.encounterID==3492)
function GetSpecializationInfo() return 252 end
driver.scripts.OnEvent(driver,'PLAYER_SPECIALIZATION_CHANGED','player')
assert(#ui.entries==2 and not NR.preview.playing)
""")

    def test_library_draft_dedup_delete_undo_and_reimport(self):
        lua,nr=runtime(True);lua.globals().NR=nr;lua.globals().note=self.dungeon_note()
        lua.execute(r'''
function GetSpecializationInfo() return 252 end
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local input,ui=NR.UI,NR.PreviewUI
input.note:SetText(note);input:Parse();input:Save();input:Play()
assert(#ui.entries==2,'saved plan and import preview must not both appear')
assert(not ui.entries[1].unsaved and ui.deletePlan.themeEnabled,'saved preview can be managed')
input:Save();input:Play();assert(#ui.entries==2,'repeat imports replace')
local changed=assert(NR.EventPlans.ParseDungeon(note));changed.plans[1].rows[1].time=17
ui:Open(changed);assert(#ui.entries==2 and ui.entries[1].unsaved)
assert(not ui.deletePlan.themeEnabled,'unsaved draft is not a deletable saved plan')
ui:OpenLibrary();local key=ui.entries[ui.choice].storageKey
local other=NR.Copy(NR.db.eventPlans[252][key]);other.specID=251
NR.db.eventPlans[251]={[key]=other}
ui.deletePlan.scripts.OnClick();assert(NR.db.eventPlans[252][key],'first click confirms only')
combat=true;ui.deletePlan.scripts.OnClick();assert(NR.db.eventPlans[252][key])
combat=false;ui.deletePlan.scripts.OnClick()
assert(not NR.db.eventPlans[252][key] and NR.db.eventPlans[251][key])
assert(#ui.entries==1 and not NR.preview.playing)
assert(not NR.EventPlans.Find(252,NR.db.deletedPlan.plan.encounterID,'mythic'))
ui.undoDelete.scripts.OnClick();assert(NR.db.eventPlans[252][key] and #ui.entries==2)
ui.deletePlan.scripts.OnClick();ui.deletePlan.scripts.OnClick()
local replacement=NR.Copy(NR.db.deletedPlan.plan);replacement.rows[1].time=19
assert(NR.EventPlans.Save(replacement));ui.undoDelete.scripts.OnClick()
assert(NR.db.eventPlans[252][key].rows[1].time==19,'undo must not overwrite a new import')
ui:OpenLibrary();ui:Select(1,false);ui.deletePlan.scripts.OnClick();ui:Select(2,false)
assert(not ui.deletePending,'changing selection cancels delete confirmation')
ui.deletePlan.scripts.OnClick();ui.deletePlan.scripts.OnClick()
ui:Select(1,false);ui.deletePlan.scripts.OnClick();ui.deletePlan.scripts.OnClick()
assert(#ui.entries==0 and not NR.preview.running and not ui.deletePlan.themeEnabled)
ui.undoDelete.scripts.OnClick();assert(#ui.entries==1)
''')

    def test_note_spec_migration_pause_rollback_and_live_isolation(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
local frost=assert(NR.ParseNote('EncounterID:3492;Difficulty:Heroic;\nph:1;time:20;spellid:51271;'))
local unholy=assert(NR.ParseNote('EncounterID:3470;Difficulty:Heroic;\nph:1;time:30;spellid:42650;'))
frost.enabled=true;unholy.enabled=true
NextRemindersDB={plans={['3492:heroic']=frost,['3470:heroic']=unholy,bad={bad=true}},previousPlans={['3492:heroic']=NR.Copy(frost)}}
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
assert(NR.NotePlans(251).plans['3492:heroic'] and NR.NotePlans(252).plans['3470:heroic'])
assert(not NR.NotePlans(251).plans['3470:heroic'] and NR.db.legacyNotePlans.plans.bad.bad)
assert(NR.NotePlans(251).previous['3492:heroic'])
assert(NR.MigrateNotePlans(251)==0)
local ui=NR.UI
ui.note:SetText('EncounterID:3492;Difficulty:Heroic;\nph:1;time:40;spellid:51271;');ui:Parse();ui:Save()
function GetSpecializationInfo() return 252 end
ui.note:SetText('EncounterID:3492;Difficulty:Heroic;\nph:1;time:50;spellid:42650;');ui:Parse();ui:Save()
function GetSpecializationInfo() return 251 end
ui.pausePlan.scripts.OnClick();assert(not NR.NotePlans(251).plans['3492:heroic'].enabled)
assert(NR.NotePlans(252).plans['3492:heroic'].enabled)
ui.rollback.scripts.OnClick();assert(NR.NotePlans(251).plans['3492:heroic'].rows[1].time==20)
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3492,'',15)
assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==51271)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
function GetSpecializationInfo() return 252 end
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3492,'',15)
assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==42650)
''')

    def test_recording_seek_preserves_manual_events_and_autoplay_finishes(self):
        lua,nr=runtime(True);lua.globals().NR=nr;lua.globals().note=self.dungeon_note()
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local bundle=assert(NR.EventPlans.ParseDungeon(note))
bundle.plans[2].rows[1].anchor='dog'
NR.PreviewUI.referenceEvents=false
assert(NR.PreviewUI:Open(bundle,2))
local p=NR.preview
assert(p.autoUse and p.video)
p:Seek(10,0);p:Event('dog',0)
assert(#p.actions==1)
p:Seek(40,0);assert(p.engine.rows[1].used)
p:Seek(0,0);assert(#p.actions==1 and not p.engine.rows[1].target)
p:Tick(40);assert(p.engine.rows[1].used,'forward playback replays the recorded event')
p:Seek(p.duration,40);assert(p.running and not p.playing and p.status=='播放结束')
p:Resume(40);assert(p.position==0 and p.playing)
p:Seek(5,40);p:Event('dog',40);assert(#p.actions==1 and p.actions[1].time==5,'editing past replaces future branch')
assert(bundle.plans[2].rows[1].time==0 and not bundle.plans[2].rows[1].used)
''')

    def test_import_visible_caret_tracks_native_position_blinks_and_cleans_up(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI;ui.frame:Show();local editor,caret=ui.note,ui.noteCaret
assert(caret.owner==editor and not caret:IsShown() and not editor.scripts.OnUpdate)
assert(editor.justifyH=='LEFT' and editor.justifyV=='TOP' and editor.blinkSpeed==0.5)
ui.notePanel.scripts.OnMouseDown(ui.notePanel,'LeftButton')
assert(editor:HasFocus() and caret:IsShown(),'an empty focused box must visibly show its insertion caret')
assert(caret:GetWidth()==2 and caret.point[2]==editor and caret.point[4]==4 and caret.point[5]==-4)
editor.scripts.OnCursorChanged(editor,0,0,0,0)
assert(caret:IsShown() and caret.point[4]==4,'empty layout callbacks cannot hide the known first insertion point')
editor.scripts.OnUpdate(editor,0.51);assert(not caret:IsShown())
editor.scripts.OnUpdate(editor,0.49);assert(caret:IsShown())
editor:SetText('中文及长行\nEncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;')
editor.scripts.OnTextChanged(editor);assert(not caret:IsShown(),'do not guess a nonempty cursor position')
editor.scripts.OnCursorChanged(editor,97,-600,1,18)
assert(caret:IsShown() and caret.point[4]==97 and caret.point[5]==-600 and caret:GetHeight()==18)
assert(editor.parent:GetVerticalScroll()==282)
editor.scripts.OnCursorChanged(editor,115,-600,1,18)
editor:SetText(editor:GetText()..'更多中文');editor.scripts.OnTextChanged(editor)
assert(caret:IsShown() and caret.point[4]==115,'native cursor-before-text callbacks must keep the real insertion position')
editor.scripts.OnCursorChanged(editor,23,-22,1,16)
assert(caret.point[4]==23 and caret.point[5]==-22 and editor.parent:GetVerticalScroll()==22)
local text=editor:GetText();ui.encounter:SetFocus()
assert(not caret:IsShown() and not editor.scripts.OnUpdate)
editor:SetFocus();assert(caret:IsShown() and caret.point[4]==23)
editor.scripts.OnEscapePressed(editor);assert(not caret:IsShown() and not editor.scripts.OnUpdate)
editor:SetFocus();ui:SetPage('settings');assert(not caret:IsShown() and not editor.scripts.OnUpdate)
ui:SetPage('import');editor:SetFocus();editor.scripts.OnHide(editor)
assert(not editor:HasFocus() and not caret:IsShown() and not editor.scripts.OnUpdate)
editor:SetFocus();editor.scripts.OnCursorChanged(editor,{secret=true},-22,1,16)
assert(not caret:IsShown() and not editor.scripts.OnUpdate)
editor.scripts.OnCursorChanged(editor,23,-22,1,16);assert(caret:IsShown())
assert(editor:GetText()==text and ui.encounter:GetText()=='' and not next(NR.NotePlans(251).plans))
''')

    def test_shared_burst_catalog_all_specs_and_web_lua_scope_match(self):
        import subprocess
        check=subprocess.run(['python','tools/sync_spell_catalog.py','--check'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(check.returncode,0,check.stderr)
        data=json.loads((ROOT/'data/burst-spells.json').read_text(encoding='utf-8'))
        lua,nr=runtime();lua.globals().NR=nr
        self.assertEqual(nr.SpellCatalog.dataVersion,data['dataVersion'])
        self.assertEqual(len(nr.SpellCatalog.spells),len(data['spells']))
        self.assertEqual(len(data['specs']),40)
        for spec in data['specs']:
            entries=nr.SpellCatalog.ForSpec(spec['id'])
            expected={r['id'] for r in data['spells'] if spec['id'] in r['specs']}
            self.assertTrue(expected)
            self.assertEqual({entries[i].id for i in range(1,len(entries)+1)},expected)
        for r in data['spells']:
            entry=nr.SpellCatalog.Get(r['id'])
            self.assertEqual(entry.name,r['name'])
            self.assertEqual(entry.icon,'Interface\\Icons\\'+r['icon'])
        self.assertIsNone(nr.SpellCatalog.Get(200166),'Havoc effect ID must not replace the cast ID')
        self.assertIsNone(nr.SpellCatalog.Get(1217607),'Devourer effect ID must not replace the cast ID')
        self.assertIsNone(nr.SpellCatalog.Get(442204),'Breath of Eons effect ID must not replace the cast ID')
        lua.execute('local x=NR.SpellCatalog.ForSpec(251);x[1].name="edited";assert(NR.SpellCatalog.Get(x[1].id).name~="edited")')

    def test_all_spec_builtin_selection_round_trips_and_cast_clears_reminder(self):
        import subprocess
        code=r"""
import {SPECS,newDungeon,generateDungeon} from './tests/fixtures/protocol/plan.mjs';
import {burstSpellsForSpec} from './tests/fixtures/protocol/spells.mjs';
const out=SPECS.map(s=>{const spell=burstSpellsForSpec(s.id)[0];const d=newDungeon(s.id);d.plans[0].rows=[{type:'spell',value:spell.id,anchor:'start',occurrence:1,time:5,window:10,hold:'',after:'ready'}];return {specID:s.id,spellID:spell.id,text:generateDungeon(d).text};});
console.log(JSON.stringify(out));
"""
        r=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(r.returncode,0,r.stderr)
        lua,nr=runtime();lua.globals().NR=nr
        for sample in json.loads(r.stdout):
            lua.globals().note=sample['text'];lua.globals().specID=sample['specID'];lua.globals().spellID=sample['spellID']
            lua.execute(r'''
local bundle,err=NR.EventPlans.ParseDungeon(note);assert(bundle,err)
local p=bundle.plans[1];assert(p.specID==specID and p.rows[1].spellID==spellID and p.rows[1].after=='ready')
local show,hide=0,0;local e=NR.Engine.New(function(kind)if kind=='show' then show=show+1 elseif kind=='hide' then hide=hide+1 end end)
e:Begin(3101,'mythic',nil,{lead=5},0,{specID=specID},p);assert(show==1)
e:Cast(spellID,1);assert(hide==1 and e.rows[1].done and e.readyWatches[e.rows[1].id])
''')

    def test_sound_pack_is_only_our_voice_clips_with_light_dropdown(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local files,kits={},{}
PlaySoundFile=function(path)files[#files+1]=path;return true end
PlaySound=function(id)kits[#kits+1]=id end
LibStub=function()return {List=function()return {'Other'} end,Fetch=function()return 'x.ogg' end} end
local s=NR.Settings({sound=true,soundChoice=('x'):rep(201)})
assert(s.soundChoice=='noel_press' and s.soundFile==nil)
local d=NR.Settings({});assert(d.soundChoice=='noel_press' and d.readySound==nil and d.missSound==nil)
assert(NR.Sounds.Find('kit:READY_CHECK','rita_ready').key=='rita_ready','old client-sound choices fall back to the default clip')
assert(NR.Sounds.Play('kit:READY_CHECK')==nil and NR.Sounds.Play('off')==nil and #files==0 and #kits==0,'unknown or off plays nothing')
-- Only "off" plus the seven bundled clips: no client sounds, no LibSharedMedia, no custom file.
local list=NR.Sounds.List();assert(list[1].key=='off' and #list==8)
for _,k in ipairs({'meow','lyl_fire_2','molly_fire_2','molly_miss_2'}) do assert(not NR.Sounds.Exists(k),k) end
for i=2,#list do local e=list[i];assert(e.file and e.voice and e.length>0)
 local f=io.open('NextReminders/Media/'..e.file:match('([%w_]+%.ogg)$'),'rb');assert(f,e.file);f:close() end
-- Reminder: one voice clip for reminders shown together; it replaces the spell-name TTS and the countdown while it plays.
NR.db.settings=NR.Settings({sound=true})
now=100;local before=#voiceCalls
-- Shown early: nothing is spoken, then 3, 2, 1, and the clip plays when time is up (once for both rows).
NR.Display:Emit('show',{id=1,spellID=42650,target=105},5);NR.Display:Emit('show',{id=2,spellID=1233448,target=105},5)
assert(#files==0 and #voiceCalls==before,'clip waits for the moment')
before=#voiceCalls
now=102;NR.Display:Emit('countdown',{id=1},3);now=103;NR.Display:Emit('countdown',{id=1},2);now=104;NR.Display:Emit('countdown',{id=1},1)
assert(#voiceCalls==before and #files==3 and files[3]:find('count_1.ogg',1,true),'recorded numbers, not TTS')
for i=#files,1,-1 do files[i]=nil end
now=104.5;NR.Display:Emit('update',{id=1},0.5);assert(#files==0)
now=105;NR.Display:Emit('update',{id=1},0);NR.Display:Emit('update',{id=2},0)
assert(#files==1 and files[1]:find('noel_press.ogg',1,true),'one clip at time-up')
NR.Display:Emit('update',{id=1},-1);assert(#files==1,'played once per reminder')
-- A countdown number while a clip still plays waits for it.
now=105.5;before=#voiceCalls;NR.Display:Emit('countdown',{id=1},3);assert(#voiceCalls==before)
-- Ready again uses the same reminder sound.
NR.Display:Clear();now=110;NR.Display:Emit('show',{id=5,spellID=42650,target=110,postReady=true},0);assert(files[#files]:find('noel_press.ogg',1,true))
-- An unused reminder that expires plays nothing more.
local e=NR.Engine.New(function(kind,row,value)NR.Display:Emit(kind,row,value)end)
NR.Display:Clear();NR.db.settings=NR.Settings({sound=true});local n=#files
now=0;e:Begin(3101,'mythic',nil,{lead=5,window=10},0,{specID=252},NR.EventPlans.New(252,3101))
now=0;e:Tick(0);now=11;NR.Display.soundUntil=nil;e:Tick(11);assert(#files==n+1,'expiry is silent')
-- A clip the client refuses: nothing plays and nothing is spoken.
NR.Display:Clear();PlaySoundFile=function()return false end
NR.db.settings=NR.Settings({sound=true,soundChoice='rita_ready'})
now=300;NR.Display:Emit('show',{id=4,spellID=42650,target=300},0);assert(#voiceCalls==0)
PlaySoundFile=function(path)files[#files+1]=path;return true end
-- The picker opens the addon's own light list: one row per clip, current one marked; a pick selects, previews and closes.
local ui=NR.UI;ui:SetPage('settings');ui:Refresh()
local pick=ui.soundPicks.soundChoice;assert(ui.soundValues.soundChoice=='rita_ready' and pick:GetText():find('丽塔',1,true))
pick.scripts.OnClick(pick);local menu=NR.Theme.menuFrame
assert(menu.shown and menu.height==8*28+12)
local shown=0;for _,row in ipairs(menu.rows)do if row.shown then shown=shown+1 end end;assert(shown==8)
assert(menu.rows[7].mark.shown and not menu.rows[2].mark.shown,'current clip is marked')
menu.rows[3].scripts.OnClick(menu.rows[3])
assert(not menu.shown and ui.soundValues.soundChoice=='lyl_fire_1' and files[#files]:find('lyl_fire_1.ogg',1,true) and pick:GetText():find('开炮',1,true))
pick.scripts.OnClick(pick);assert(menu.shown);pick.scripts.OnClick(pick);assert(not menu.shown,'clicking the field again closes it')
ui:SaveSettings();assert(NR.db.settings.soundChoice=='lyl_fire_1' and NR.db.settings.soundFile==nil)
LibStub=nil
''')

    def test_catalog_public_native_metadata_fallback_and_plugin_command(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local before=NR.Copy(NR.db)
C_Spell.GetSpellInfo=function()return nil end
local name,icon=NR.SpellCatalog.Info(42650);assert(name=='亡者大军' and icon=='Interface\\Icons\\spell_deathknight_armyofthedead')
local action,texture,id=NR.EventPlans.Action({spellID=42650});assert(action==name and texture==icon and id==42650)
NR.Display:Emit('show',{id=42,spellID=42650,target=5},5)
assert(NR.Display.rows[42].label:GetText()=='亡者大军' and #voiceCalls==0)
C_Spell.GetSpellInfo=function()return {name={secret=true},iconID={secret=true}} end
assert(NR.SpellCatalog.Info(42650)=='亡者大军')
C_Spell.GetSpellInfo=function()error('API unavailable')end;assert(NR.SpellCatalog.Info(42650)=='亡者大军')
C_Spell.GetSpellInfo=function(id)assert(type(id)=='number');return {name='Localized game name',iconID=321} end
local a,b=NR.SpellCatalog.Info(42650);assert(a=='Localized game name' and b==321)
assert(NR.SpellCatalog.Info({secret=true})=='提醒')
assert(not NR.SpellCatalog.Get({secret=true}) and #NR.SpellCatalog.ForSpec({secret=true})==0)
C_Spell=nil;assert(NR.SpellCatalog.Info(999999)=='技能 999999')
NR.Display:Clear();combat=true;SlashCmdList.NEXTREMINDERS('spells')
local found=false;for _,message in ipairs(messages)do if message:find('冰霜之柱',1,true)and message:find('51271',1,true)then found=true end end;assert(found)
assert(NR.db.settings.lead==before.settings.lead and not next(NR.db.eventPlans),'catalog command does not create policies')
''')

    def test_import_editor_click_focus_feedback_cursor_scroll_and_escape(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI;ui.frame:Show();local editor,scroll=ui.note,ui.note.parent
assert(not editor:HasFocus() and editor.autoFocus==false and editor.mouseEnabled)
assert(ui.noteHint:IsShown() and ui.noteFocus:GetText()=='点击输入')
ui.notePanel.scripts.OnMouseDown(ui.notePanel,'RightButton');assert(not editor:HasFocus())
ui.notePanel.scripts.OnMouseDown(ui.notePanel,'LeftButton')
assert(editor:HasFocus() and ui.noteFocus:GetText()=='正在输入' and not ui.noteHint:IsShown())
assert(ui.notePanel.borderColor==NR.Theme.colors.ink)
editor.scripts.OnCursorChanged(editor,4,-600,1,16)
assert(scroll:GetVerticalScroll()==280 and editor:GetHeight()>=624,'caret must stay in the visible scroll area')
editor.scripts.OnCursorChanged(editor,4,0,1,16);assert(scroll:GetVerticalScroll()==0)
ui.encounter:SetFocus();assert(not editor:HasFocus() and ui.noteFocus:GetText()=='点击输入')
assert(ui.notePanel.borderColor==NR.Theme.colors.border)
scroll.scripts.OnMouseDown(scroll,'LeftButton');assert(editor:HasFocus())
editor:SetText('EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;')
editor.scripts.OnTextChanged(editor);ui:Parse();local parsed=ui.preview;assert(parsed)
editor.scripts.OnEscapePressed(editor)
assert(not editor:HasFocus() and not ui.noteHint:IsShown() and ui:CurrentPlan()==parsed)
editor.scripts.OnMouseDown(editor,'LeftButton');ui:SetPage('settings');assert(not editor:HasFocus())
ui:SetPage('import');assert(not editor:HasFocus() and editor:GetText():find('EncounterID:3492'))
editor:SetFocus();ui.importPage:Hide();assert(not editor:HasFocus())
assert(ui.encounter:GetText()=='','focus fix must not invent an encounter number')
''')

    def test_voice_countdown_prepare_then_five_to_one_recorded_cues(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:20;spellid:51271;")
local events={}
local p=NR.Preview.New(function(kind,row,value) events[#events+1]={kind=kind,value=value} end,function() end)
assert(p:Start(plan,{lead=10,countdown=true},{},1000))
assert(p:Seek(9.9,1000)); assert(not p.engine.rows[1].shown,'not before 10s')
assert(p:Seek(12.9,1000)); assert(p.engine.rows[1].shown)
local t=12.9
while t<20.5 do t=t+0.05; p:Tick(1000+t-12.9) end
local seq={}
for _,e in ipairs(events) do if e.kind=='countdown' then seq[#seq+1]=tostring(e.value) end end
assert(table.concat(seq,',')=='prepare,5,4,3,2,1',table.concat(seq,','))
-- Countdown off keeps the old 5s lead and says nothing.
events={}
assert(p:Start(plan,{lead=5,countdown=true},{},1000)); assert(p:Seek(14.5,1000)); assert(not p.engine.rows[1].shown,'lead is exactly what was entered')
assert(p:Seek(15.2,1000)); assert(p.engine.rows[1].shown)
events={}; assert(p:Seek(19.9,1000)); for _,e in ipairs(events) do assert(e.value~='prepare','no room for 准备爆发 under 7s') end
events={}
assert(p:Start(plan,{lead=5,countdown=false},{},1000))
assert(p:Seek(19.9,1000)); for _,e in ipairs(events) do assert(e.kind~='countdown') end
p:Stop()
-- Display: "准备爆发" replaces the spell-name TTS; numbers are recorded clips.
files={};PlaySoundFile=function(path)files[#files+1]=path;return true end
NR.db.settings=NR.Settings({countdown=true,sound=true})
NR.Display:Clear(); now=200; local v=#voiceCalls
NR.Display:Emit('show',{id=1,spellID=51271,target=207},7); assert(#voiceCalls==v,'nothing is spoken')
now=200.6; NR.Display:Emit('countdown',{id=1},'prepare'); assert(files[#files]:find('prep_burst.ogg',1,true))
now=200.6; NR.Display:Emit('countdown',{id=2},'prepare'); assert(not files[#files-1] or not files[#files-1]:find('prep_burst',1,true),'two rows share one prepare')
for n=5,1,-1 do now=207-n; NR.Display:Emit('countdown',{id=1},n); assert(files[#files]:find('count_'..n..'.ogg',1,true)) end
assert(#voiceCalls==v)
now=207; NR.Display:Emit('update',{id=1},0); assert(files[#files]:find('noel_press.ogg',1,true))
-- Shown late (no room to prepare): still nothing is spoken.
NR.Display:Clear(); now=300; NR.Display:Emit('show',{id=3,spellID=51271,target=304},4); assert(#voiceCalls==v)
''')

    def test_sound_delete_restore_default_noel_and_test_position(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
NextRemindersDB={settings={soundChoice='meow',sound=false,lead=5,window=10,volume=65,tts=true,glow='player',voice=3}}
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local st=NR.db.settings;assert(st.lead==10 and st.window==5 and st.sound==true and NR.db.defaultsVersion==3,'old defaults move once')
assert(st.volume==nil and st.tts==nil and st.glow==nil and st.voice==nil,'removed settings are dropped')
assert(NR.db.settings.soundChoice=='noel_press' and NR.db.soundDefault==2,'old default moves to 诺艾尔 once')
NR.db.settings.soundChoice='molly_fire_1'
local files={};PlaySoundFile=function(path)files[#files+1]=path;return true end
local ui=NR.UI;ui:SetPage('settings');ui:Refresh()
local pick=ui.soundPicks.soundChoice;assert(ui.soundValues.soundChoice=='molly_fire_1')
pick.scripts.OnClick(pick);local menu=NR.Theme.menuFrame
assert(not menu.rows[1].remove.shown,'"off" cannot be deleted') ;assert(menu.rows[2].remove.shown)
-- Delete the clip in use: the choice moves to 诺艾尔 and is saved.
local meowRow;for _,row in ipairs(menu.rows)do if row.shown and row.item.key=='molly_fire_1' then meowRow=row end end
meowRow.remove.scripts.OnClick(meowRow.remove)
assert(NR.Sounds.IsHidden('molly_fire_1') and NR.db.hiddenSounds.molly_fire_1 and ui.soundValues.soundChoice=='noel_press' and NR.db.settings.soundChoice=='noel_press')
assert(menu.shown and #NR.Sounds.List()==7)
local last;for _,row in ipairs(menu.rows)do if row.shown then last=row end end
assert(last.item.key=='__restore' and last.caption:GetText():find('（1）',1,true) and not last.remove.shown)
assert(NR.Sounds.Play('molly_fire_1')==nil,'a deleted clip never plays')
assert(NR.Sounds.Find('molly_fire_1','noel_press').key=='noel_press')
last.scripts.OnClick(last);assert(not NR.Sounds.IsHidden('molly_fire_1') and #NR.Sounds.List()==8 and menu.shown)
-- Deleting every clip leaves only "off".
for _,e in ipairs(NR.Sounds.List())do NR.Sounds.Remove(e.key) end
assert(#NR.Sounds.List()==1 and NR.Sounds.Find('noel_press','noel_press').key=='off')
NR.Sounds.RestoreAll()
-- /nr test (no player window) stays where real reminders appear.
menu:Hide();ui.frame:Hide();NR.PreviewUI.frame:Hide()
SlashCmdList.NEXTREMINDERS("test")
assert(not NR.Display.previewMode and NR.Display.container.point[1]=='TOP' and NR.Display.container.point[5]==-144)
''')

    def test_display_future_countdown_due_now_waiting_and_translucent_background(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
NR.db.settings.countdown=false;NR.db.settings.lead=5
local plan=assert(NR.ParseNote('EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;'))
assert(NR.PreviewUI:Open(plan));assert(not NR.Display.rows[1])
NR.preview:Tick(5)
local row=NR.Display.rows[1];assert(row:IsShown() and row.time:GetText()=='5秒')
assert(row.backdropColor[4]>0 and row.backdropColor[4]<=0.2)
assert(row.backdropBorderColor[4]<=0.3)
NR.preview:Tick(6);assert(row.time:GetText()=='4秒')
NR.preview:Tick(7);assert(row.time:GetText()=='3秒')
NR.preview:Tick(8);assert(row.time:GetText()=='2秒')
NR.preview:Tick(9);assert(row.time:GetText()=='1秒')
NR.preview:Tick(9.99);assert(row.time:GetText()=='1秒','positive remaining time must not say now')
NR.preview:Tick(10);assert(row.time:GetText()=='现在')
NR.preview:Tick(11);assert(row.time:GetText()=='现在')
assert(#voiceCalls==0,'visual countdown works with voice countdown disabled')
NR.preview:Stop();assert(not row:IsShown())
local events=NR.EventPlans.New(252,3101)
NR.PreviewUI.referenceEvents=false
assert(NR.PreviewUI:Open(events))
assert(NR.Display.rows['event:1'].time:GetText()=='现在','opening time 0 is already due, lead does not delay it')
assert(NR.Display.rows['event:2'].time:GetText()=='等待','unknown future event must not get a fake countdown')
assert(NR.preview:Event('vuln',0))
assert(NR.Display.rows['event:2'].time:GetText()=='2秒')
NR.preview:Tick(1);assert(NR.Display.rows['event:2'].time:GetText()=='1秒')
NR.preview:Tick(2);assert(NR.Display.rows['event:2'].time:GetText()=='现在')
NR.Display:Emit('hold',{id='event:2',hold='再次等待'})
assert(NR.Display.rows['event:2'].time:GetText()=='等待','a reused row must clear its old timer')
NR.preview:Stop()
''')

    @staticmethod
    def dungeon_note():
        import subprocess
        code="import {newDungeon,newPlan,generateDungeon} from './tests/fixtures/protocol/plan.mjs';const d=newDungeon();d.plans[0]=newPlan();d.plans[3].rows=[{type:'spell',value:42650,anchor:'start',occurrence:1,time:0,window:10,hold:''}];process.stdout.write(generateDungeon(d).text);"
        return subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout

    def test_dungeon_catalog_matches_runtime_all_bosses_and_scopes(self):
        import subprocess
        data=json.loads(subprocess.run(['node','--input-type=module','-e',"import {DUNGEONS} from './tests/fixtures/protocol/plan.mjs';console.log(JSON.stringify(DUNGEONS));"],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout)
        lua,nr=runtime()
        self.assertEqual(len(data),8)
        ids=[]
        for d in data:
            live=nr.DungeonData.dungeons[d['id']]
            self.assertEqual(live.name,d['name'])
            self.assertEqual(list(live.bosses.values()),[b[0] for b in d['bosses']])
            ids.extend(b[0] for b in d['bosses'])
        self.assertEqual(len(ids),28);self.assertEqual(len(set(ids)),28)
        self.assertNotIn(3492,ids)

    def test_dungeon_bundle_round_trip_and_reject_partial_invalid_input(self):
        note=self.dungeon_note();lua,nr=runtime();lua.globals().NR=nr;lua.globals().note=note
        lua.execute(r"""
local b=assert(NR.EventPlans.ParseDungeon(note));assert(b.dungeonID==2813 and b.specID==252 and #b.plans==2)
assert(b.plans[1].rows[2].after=='ready' and b.plans[2].encounterID==3105)
assert(not NR.EventPlans.ParseDungeon(note:gsub('NRDungeon:1','NRDungeon:2')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('DungeonID:2813','DungeonID:2993')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('EncounterID:3105','EncounterID:3492')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('EncounterID:3105','EncounterID:3101')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('SpecID:252','SpecID:251',1)))
assert(not NR.EventPlans.ParseDungeon(note:gsub('NRDungeon:1;','NRDungeon:1;Unknown:x;')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('DungeonID:2813;','DungeonID:2813;DungeonID:2813;')))
assert(not NR.EventPlans.ParseDungeon(note:gsub('Name:[^;]*','Name:%%XY',1)))
assert(not NR.EventPlans.ParseDungeon(note..note))
assert(not NR.EventPlans.ParseDungeon(note:match('^[^\n]*')))
assert(not NR.EventPlans.ParseDungeon(note..'anchor:start;occurrence:1;time:0;window:10;spellid:broken;'))
assert(not NR.EventPlans.ParseDungeon(string.rep('x',200001)))
assert(NR.EventPlans.Parse(note:match('(NRPlan:2;EncounterID:3101.-)NRPlan:2;EncounterID:3105')))
""")

    def test_dungeon_save_is_atomic_full_scope_pause_and_rollback(self):
        lua,nr=runtime(True);lua.globals().NR=nr;lua.globals().note=self.dungeon_note()
        lua.execute(r"""
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local b=assert(NR.EventPlans.ParseDungeon(note))
local old=NR.EventPlans.New(252,3101);old.rows[2].time=7;assert(NR.EventPlans.Save(old))
local omitted=NR.Copy(old);omitted.encounterID=3102;omitted.rows={omitted.rows[1]};assert(NR.EventPlans.Save(omitted))
local other=NR.Copy(omitted);other.specID=251;assert(NR.EventPlans.Save(other))
local hero=NR.Copy(omitted);hero.difficulty='heroic';assert(NR.EventPlans.Save(hero))
NR.NotePlans(251).plans['3492:heroic']={unchanged=true}
local invalid=NR.Copy(b);invalid.plans[2].encounterID=3457
assert(not NR.EventPlans.SaveDungeon(invalid));assert(NR.EventPlans.Get(252,3101,'mythic').rows[2].time==7)
combat=true;assert(not NR.EventPlans.SaveDungeon(b));combat=false
assert(NR.EventPlans.SaveDungeon(b));assert(not NR.EventPlans.Get(252,3102,'mythic'))
assert(NR.EventPlans.Get(251,3102,'mythic') and NR.EventPlans.Get(252,3102,'heroic') and NR.NotePlans(251).plans['3492:heroic'].unchanged)
assert(NR.EventPlans.OwnsDungeonEncounter(252,3102) and not NR.EventPlans.OwnsDungeonEncounter(251,3102))
local last=NR.db.lastDungeon;assert(NR.EventPlans.PauseDungeon(last));assert(not NR.EventPlans.Get(252,3101,'mythic') and not NR.EventPlans.Get(252,3105,'mythic'))
assert(NR.EventPlans.RollbackDungeon(last));assert(NR.EventPlans.Get(252,3101,'mythic').rows[2].time==7)
assert(NR.EventPlans.Get(252,3102,'mythic') and not NR.EventPlans.Find(252,3105,'mythic'))
assert(not NR.EventPlans.OwnsDungeonEncounter(252,3102))
assert(NR.EventPlans.RollbackDungeon(last));assert(NR.EventPlans.OwnsDungeonEncounter(252,3102))
assert(NR.EventPlans.Find(252,3105,'mythic').enabled==false)
local backup=NR.db.previousDungeons['252:2813'];backup.entries['3105:mythic']={kind='broken'}
assert(not NR.EventPlans.RollbackDungeon(last));assert(NR.EventPlans.OwnsDungeonEncounter(252,3102))
assert(not NR.EventPlans.RollbackDungeon({specID='bad'}))
""")

    def test_dungeon_real_ui_import_preview_switch_and_encounter_matching(self):
        lua,nr=runtime(True);lua.globals().NR=nr;lua.globals().note=self.dungeon_note()
        lua.execute(r"""
function GetSpecializationInfo() return 252 end
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
NR.UI.note:SetText(note);NR.UI:Parse();assert(NR.UI.preview.kind=='dungeon')
NR.UI:Play();assert(NR.preview.plan.encounterID==3101 and #NR.PreviewUI.entries==2)
NR.PreviewUI.entryButtons[2].scripts.OnClick();assert(NR.preview.plan.encounterID==3105 and not NR.preview.playing)
NR.PreviewUI.entryButtons[1].scripts.OnClick();assert(NR.preview.plan.encounterID==3101)
NR.UI:Save();assert(NR.db.lastPlanKind=='dungeon' and NR.EventPlans.Get(252,3105,'mythic'))
NR.NotePlans(251).plans['3101:mythic']=assert(NR.ParseNote('{time:00:00} - player {spell:51271}',{encounterID=3101}))
NR.NotePlans(251).plans['3102:mythic']=assert(NR.ParseNote('{time:00:00} - player {spell:51271}',{encounterID=3102}))
NR.NotePlans(251).plans['3101:mythic'].enabled=true;NR.NotePlans(251).plans['3102:mythic'].enabled=true
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8);assert(not NR.preview.running and #NR.engine.rows==4)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3105,'',8);assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==42650)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3102,'',8);assert(#NR.engine.rows>0,'omitted boss uses built-in burst reminders')
for _,row in ipairs(NR.engine.rows) do assert(row.auto,'omitted boss must not fall back to legacy static notes') end
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3105,'',23);assert(#NR.engine.rows==0,'M+ bundle must not run in ordinary mythic')
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
function GetSpecializationInfo() return 251 end
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8);assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==51271)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
function GetSpecializationInfo() return 252 end
SlashCmdList.NEXTREMINDERS('preview');assert(NR.preview.plan.encounterID==3101 and #NR.PreviewUI.entries==2)
NR.preview:Stop();NR.PreviewUI.frame:Hide()
NR.UI.note:SetText(note..'broken');NR.UI:Save();assert(NR.db.lastPlanKind=='dungeon')
NR.UI:Parse();assert(not NR.UI.preview)
NR.UI.pausePlan.scripts.OnClick();assert(not NR.EventPlans.Get(252,3105,'mythic'))
""")

    def test_dungeon_all_catalog_bosses_load_without_special_event_definition(self):
        import subprocess
        code="import {DUNGEONS,newDungeon,generateDungeon} from './tests/fixtures/protocol/plan.mjs';const notes=DUNGEONS.map(d=>{const p=newDungeon(252,d.id);for(const b of p.plans)b.rows=[{type:'spell',value:1233448,anchor:'start',occurrence:1,time:0,window:10,hold:'',after:'ready'}];return generateDungeon(p).text;});console.log(JSON.stringify(notes));"
        notes=json.loads(subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout)
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute("function GetSpecializationInfo() return 252 end;created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')")
        for note in notes:
            lua.globals().note=note
            lua.execute(r"""
local b=assert(NR.EventPlans.ParseDungeon(note));assert(NR.EventPlans.SaveDungeon(b))
local driver=created[1]
for _,p in ipairs(b.plans) do
 driver.scripts.OnEvent(driver,'ENCOUNTER_START',p.encounterID,'',8)
 assert(#NR.engine.rows==1 and NR.engine.rows[1].shown and NR.engine.rows[1].spellID==1233448)
 driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player',0,1233448)
 assert(NR.engine.rows[1].done)
 driver.scripts.OnEvent(driver,'ENCOUNTER_END');assert(not NR.engine.active)
end
""")

    def test_dungeon_generation_empty_defaults_validation_and_snapshot(self):
        import subprocess
        code=r"""
import assert from 'node:assert/strict';
import {SPECS,newDungeon,generateDungeon,validateDungeon} from './tests/fixtures/protocol/plan.mjs';
for(const spec of SPECS){
  const empty=newDungeon(spec.id);assert(validateDungeon(empty,true));
  assert(empty.plans.every(p=>p.rows.length===0),'new drafts must not impose a spec strategy');
  assert.throws(()=>generateDungeon(empty),/至少/);
}
const d=newDungeon();
d.plans[3].rows=[{type:'spell',value:42650,anchor:'dog',occurrence:1,time:3,window:10,hold:'等放狗',after:'ready'}];
const g=generateDungeon(d);assert.equal(g.bundle.plans.length,1);assert.equal(g.bundle.plans[0].encounterID,3105);
assert(g.text.includes('anchor:dog;occurrence:1;time:3.0;'));assert(g.text.includes('after:ready;'));
d.plans[3].rows[0].time=20;assert.equal(g.bundle.plans[0].rows[0].time,3);
assert(d.plans.slice(0,3).every(p=>!p.rows.length),'configuring one boss must not populate others');
const bad=structuredClone(d);bad.plans[1].rows=[{...d.plans[3].rows[0],anchor:'dog'}];assert.throws(()=>generateDungeon(bad),/首领|事件/);
const other=newDungeon(62);assert(other.plans.every(p=>!p.rows.length));
console.log('empty defaults / selected boss / validation / snapshot PASS');
"""
        r=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(r.returncode,0,r.stderr)

    def test_unavailable_opener_waits_and_repeats_without_initial_cast(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local state='cooling'
local shown=0
local e=NR.Engine.New(function(k) if k=='show' then shown=shown+1 end end,nil,function()return state end)
local p=NR.EventPlans.New(252,3101)
p.rows={{id=1,spellID=42650,anchor='start',occurrence=1,time=0,window=10}}
e:Begin(3101,'mythic',nil,{},0,{specID=252},p)
assert(shown==0 and e.readyWatches['event:1'].waiting)
e:Tick(60);assert(shown==0,'opening wait must survive the original window')
state=nil;e:CooldownUpdate(61);assert(shown==0,'unknown does not mean ready')
state='ready';e:Tick(80);assert(shown==1 and e.rows[1].target==80)
e:Tick(81);assert(shown==1)
e:Cast(42650,82);state='cooling';e:CooldownUpdate(83)
state='ready';e:Tick(140);assert(shown==2 and e.rows[1].target==140)
e:Stop();e:Tick(200);assert(shown==2)
assert(p.rows[1].after==nil,'runtime defaults do not mutate the saved plan')
''')

    def test_phase_cooldown_skips_occurrence_and_does_not_late_replay(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local state='cooling';local shown=0
local e=NR.Engine.New(function(k)if k=='show' then shown=shown+1 end end,nil,function()return state end)
local p=NR.EventPlans.New(252,3101)
p.rows={{id=1,spellID=42650,anchor='vuln',every=true,time=0,window=10}}
e:Begin(3101,'mythic',nil,{},0,{specID=252},p)
e:BossEvent({key='vuln',count=1,at=30},30)
assert(shown==0 and e.rows[1].done)
state='ready';e:Tick(31)
e:BossEvent({key='vuln',count=1,at=30.2},31)
assert(shown==0,'same occurrence must not replay after cooldown finishes')
e:BossEvent({key='vuln',count=2,at=60},60);assert(shown==1)
state='cooling';e:CooldownUpdate(61)
assert(not e.rows[1].shown,'already visible reminder is hidden during cooldown')
state='ready';e:Tick(62);assert(shown==1)
''')

    def test_ready_event_order_gcd_only_and_late_anchor_correction(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local info={isEnabled=true,isActive=true,isOnGCD=true}
C_Spell.GetSpellCooldown=function()return info end
local output=0
local e=NR.Engine.New(function(k,r)if k=='show' and r.postReady then output=output+1 end end)
local p=NR.EventPlans.New(252,3101);p.rows={p.rows[2]}
e:Begin(3101,'mythic',nil,{},0,{specID=252},p);e:Warning(1,30);e:Cast(42650,32)
e:CooldownUpdate(32.1);info.isActive=false;e:Tick(35);assert(output==0,'GCD alone must not arm a cooldown cycle')
info.isActive=true;info.isOnGCD=false;e:CooldownUpdate(40);info.isActive=false;e:Tick(80);assert(output==1)
e:BossEvent({key='vuln',count=1,at=31.7,predicted=false},80.1)
assert(e.rows[1].target==80 and e.rows[1].shown,'late anchor correction must not overwrite post-ready reminder')
e:Stop();info.isActive=true
e:Begin(3101,'mythic',nil,{},0,{specID=252},p);e:Warning(1,30)
e:CooldownUpdate(32);e:Cast(42650,32.1)
assert(e.readyWatches['event:2'].armed,'cooldown event before cast notification is retained briefly')
info.isActive=false;e:Tick(80);assert(output==2)
''')

    def test_after_first_cast_real_cooldown_edges_voice_once_and_stop(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
function GetSpecializationInfo() return 252 end
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
readyCalls={};local emit=NR.Display.Emit
NR.Display.Emit=function(self,kind,row,value) if kind=='show' and row and row.postReady then readyCalls[#readyCalls+1]=row.id end return emit(self,kind,row,value) end
local cd={}
C_Spell.GetSpellCooldown=function(id)
 return setmetatable({isEnabled=true,isActive=cd[id]=='cooling',isOnGCD=false},{__index=function(_,key)error('numeric cooldown field read: '..key)end})
end
local p=NR.EventPlans.New(252,3101);assert(NR.EventPlans.Save(p))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8)
now=0;driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',1233448)
assert(not next(NR.engine.readyWatches),'opener must not unlock post-vulnerability readiness')
now=30;driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',{severity=1})
now=32;driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',42650)
assert(NR.engine.readyWatches['event:2'])
local before=#readyCalls
NR.engine:Tick(32.2);assert(#readyCalls==before,'ready immediately after cast is not a completed cooldown edge')
cd[42650]='cooling';now=33;driver.scripts.OnEvent(driver,'SPELL_UPDATE_COOLDOWN',{secret=true});NR.engine:Tick(33);assert(#readyCalls==before)
cd[42650]='ready';NR.engine:Tick(80)
assert(#readyCalls==before+1 and #voiceCalls==0,'one ready-again reminder, nothing spoken')
NR.engine:Tick(81);NR.engine:Tick(92);assert(#readyCalls==before+1,'one voice per edge')
cd[42650]='cooling';NR.engine:CooldownUpdate(93);NR.engine:Tick(93);cd[42650]='ready';NR.engine:Tick(140)
assert(#readyCalls==before+2,'voice repeats after the next real cooldown')
driver.scripts.OnEvent(driver,'ENCOUNTER_END');cd[42650]='cooling';NR.engine:Tick(150);cd[42650]='ready';NR.engine:Tick(200)
assert(#readyCalls==before+2 and not next(NR.engine.readyWatches))
now=220;driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8)
now=250;driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',{severity=1})
now=252;driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',42650)
assert(next(NR.engine.readyWatches));driver.scripts.OnEvent(driver,'PLAYER_ENTERING_WORLD')
assert(not NR.engine.active and not next(NR.engine.readyWatches))
-- Pressed long after the reminder expired: the first use still starts ready reminders.
now=300;driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8)
now=330;driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',{severity=1})
NR.engine:Tick(360);assert(NR.engine.rows[2].done and not NR.engine.rows[2].used,'vulnerability reminder expired unused')
now=400;driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',42650)
assert(NR.engine.readyWatches['event:2'],'late first use unlocks ready reminders')
cd[42650]='cooling';NR.engine:CooldownUpdate(401);NR.engine:Tick(401);before=#readyCalls;cd[42650]='ready';NR.engine:Tick(500)
assert(#readyCalls==before+1,'late first use still voices the next ready')
''')

    def test_ready_public_flags_secrets_gcd_charges_and_disabled_cases(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local info={isEnabled=true,isActive=true,isOnGCD=false}
C_Spell.GetSpellCooldown=function()return info end
assert(NR.Ready.State(42650,true)=='cooling')
assert(NR.Ready.State(42650)==nil,'isOnGCD cannot be trusted from a poll')
info.isOnGCD=true;assert(NR.Ready.State(42650,true)=='ready')
info.isActive=false;info.isOnGCD=false;assert(NR.Ready.State(42650)=='ready')
for _,key in ipairs({'isEnabled','isActive','isOnGCD'}) do
 local saved=info[key];info[key]={secret=true}
 if key=='isOnGCD' then info.isActive=true end
 assert(NR.Ready.State(42650,true)==nil);info[key]=saved;info.isActive=false
end
info.isEnabled=false;assert(NR.Ready.State(42650)==nil);info.isEnabled=true
local charges={maxCharges=2,isActive=true};C_Spell.GetSpellCharges=function()return charges end
assert(NR.Ready.State(42650)=='cooling')
charges.isActive=false;assert(NR.Ready.State(42650)=='ready')
charges.maxCharges={secret=true};assert(NR.Ready.State(42650)==nil)
C_Spell.GetSpellCharges=function()return nil end
C_Spell.GetSpellCooldown=function()error('unavailable')end;assert(NR.Ready.State(42650)==nil)
assert(NR.Ready.State({secret=true})==nil)
''')

    def test_after_ready_codec_rejects_old_version_and_bad_combinations(self):
        import subprocess
        code="import {newPlan,exportPlan} from './tests/fixtures/protocol/plan.mjs';process.stdout.write(exportPlan(newPlan()));"
        r=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True)
        lua,nr=runtime();lua.globals().NR=nr;lua.globals().note=r.stdout
        lua.execute(r'''
local p=assert(NR.EventPlans.Parse(note));assert(p.rows[2].after=='ready' and p.rows[3].after=='ready' and not p.rows[1].after)
assert(not NR.EventPlans.Parse(note:gsub('NRPlan:2','NRPlan:1')),'version1 must reject new semantics')
local old=note:gsub('NRPlan:2','NRPlan:1'):gsub('after:ready;','');assert(NR.EventPlans.Parse(old))
assert(not NR.EventPlans.Parse(note:gsub('spellid:42650','spellid:broken')))
assert(not NR.EventPlans.Parse(note:gsub('occurrence:1','occurrence:every')))
assert(not NR.EventPlans.Parse(note:gsub('spellid:42650','text:test')))
p.rows[1].after='ready';assert(not NR.EventPlans.Validate(p),'duplicate readiness for the same spell is ambiguous')
''')

    def test_ready_preview_is_manual_replayable_and_does_not_read_live_cd(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
C_Spell.GetSpellCooldown=function()error('preview read live cooldown')end
local plan=NR.EventPlans.New(252,3101);plan.rows={plan.rows[2]}
local p=NR.Preview.New(function()end)
assert(p:Start(plan,{}, {specID=252},0))
assert(not p:Ready(0),'must use the first event reminder before post-ready')
assert(p:Event('vuln',0));p:UseRow('event:2',2)
p:Tick(3);assert(p.running and not p.engine.rows[1].shown)
assert(p:Ready(4));assert(p.engine.rows[1].postReady and p.engine.rows[1].shown)
assert(p:Seek(3,5));assert(p.engine.readyWatches['event:2'] and not p.engine.rows[1].shown)
assert(p:Ready(6));assert(p.engine.rows[1].shown)
p:Stop();assert(not next(p.engine.readyWatches))
''')

    def test_event_reimport_pause_rollback_and_master_switch_scope(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
function GetSpecializationInfo() return 252 end
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
local p=NR.EventPlans.New(252,3101);assert(NR.EventPlans.Save(p));p.rows[2].time=3;assert(NR.EventPlans.Save(p))
NR.db.lastPlanKind='events';NR.db.lastEventPlan={specID=252,encounterID=3101,difficulty='mythic'}
NR.UI.pausePlan.scripts.OnClick();assert(not NR.EventPlans.Get(252,3101,'mythic'))
NR.UI.rollback.scripts.OnClick();assert(NR.EventPlans.Get(252,3101,'mythic').rows[2].time==0)
NR.UI.enableButton.scripts.OnClick();assert(not NR.db.enabled)
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8);assert(#NR.engine.rows==0)
driver.scripts.OnEvent(driver,'ENCOUNTER_END');NR.UI.enableButton.scripts.OnClick();assert(NR.db.enabled)
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8);assert(#NR.engine.rows==4)
assert(not NR.EventPlans.Get(nil,nil,nil));assert(not NR.EventPlans.Rollback({specID='broken'}))
''')
    def test_web_exports_round_trip_real_lua_and_refuse_lossy_conversion(self):
        import subprocess
        code=r'''
import {SPECS,newPlan,exportPlan} from './tests/fixtures/protocol/plan.mjs';
import assert from 'node:assert/strict';
assert.equal(SPECS.length,40);assert.equal(new Set(SPECS.map(s=>s.id)).size,40);
const p=newPlan();p.rows[1].hold='留着;等%易伤\n第二行';
assert.throws(()=>exportPlan(p,'nsrt'));assert.throws(()=>exportPlan(p,'mrt'));
const staticPlan={...p,rows:[p.rows[0]]};
process.stdout.write(JSON.stringify({nr:exportPlan(p),mrt:exportPlan(staticPlan,'mrt'),nsrt:exportPlan(staticPlan,'nsrt')}));
'''
        r=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True)
        notes=json.loads(r.stdout)
        lua,nr=runtime();lua.globals().NR=nr
        for key,note in notes.items(): lua.globals()[key]=note
        lua.execute(r'''
local p=assert(NR.EventPlans.Parse(nr)); assert(p.specID==252 and #p.rows==4)
assert(p.rows[2].hold=='留着;等%易伤\n第二行' and p.rows[2].anchor=='vuln' and p.rows[2].occurrence==1)
assert(p.rows[4].label=='药水与主动饰品')
assert(NR.ParseNote(mrt,{encounterID=3101}).rows[1].spellID==1233448)
assert(NR.ParseNote(nsrt).rows[1].tag=='252')
assert(not NR.EventPlans.Parse(nr:gsub('NRPlan:2','NRPlan:99')))
assert(not NR.EventPlans.Parse(nr:gsub('SpecID:252;','SpecID:252;SpecID:251;')))
assert(not NR.EventPlans.Parse(nr:gsub('anchor:vuln','anchor:unknown')))
assert(not NR.EventPlans.Parse(nr:gsub('hold:','unknown:')))
assert(not NR.EventPlans.Parse(nr:gsub('Name:[^;]*','Name:%%XY')))
assert(not NR.EventPlans.Parse('NRPlan:1;EncounterID:3101;Difficulty:mythic;SpecID:252;'))
''')

    def test_warning_event_policy_first_only_hold_and_boundary(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local p=NR.EventPlans.New(252,3101);local output={}
local e=NR.Engine.New(function(k,r,v) output[#output+1]={k,r.id,v} end)
e:Begin(3101,'mythic',nil,{},0,{specID=252},p)
assert(#e.rows==4 and e.rows[1].shown and e.rows[2].held and not e.rows[3].shown)
e:Cast(1233448,0);assert(e.rows[1].done and not e.rows[3].done)
e:Warning({secret=true},30);e:Warning(0,30);assert(not e.rows[2].target)
e:Warning(1,30);assert(e.rows[2].target==31.7 and e.rows[2].shown and not e.rows[2].held)
e:Warning(1,30.1);assert(e.bossEvents.counts.vuln==1)
assert(not e.bossEvents:Check('vuln',31.6,0,10))
assert(e.bossEvents:Check('vuln',31.7,0,10) and not e.bossEvents:Check('vuln',41.7,0,10))
e:Cast(42650,31.7);assert(e.rows[2].done)
e:Warning(1,70);assert(e.bossEvents.counts.vuln==2 and not e.rows[2].shown)
e:Stop();assert(not e.active and not e.bossEvents)
local other=NR.Engine.New();other:Begin(3105,'mythic',nil,{},0,{specID=252},p)
other:Warning(1,30);assert(#other.rows==0 and not other.bossEvents.records.vuln)
other:Begin(3101,'heroic',nil,{},0,{specID=252},p);other:Warning(1,30);assert(#other.rows==0)
other:Begin(3101,'mythic',nil,{},0,{specID=251},p);assert(#other.rows==0)
''')

    def test_event_repeat_second_occurrence_and_future_reminders(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local p=NR.EventPlans.New(252,3101);p.rows={p.rows[2],p.rows[3]}
p.rows[1].after=nil;p.rows[2].after=nil
p.rows[1].every=true;p.rows[1].occurrence=nil;p.rows[2].occurrence=2
local e=NR.Engine.New();e:Begin(3101,'mythic',nil,{},0,{specID=252},p)
e:Warning(1,20);assert(e.rows[1].shown and not e.rows[2].shown)
e:Cast(42650,21.7);assert(e.rows[1].done)
e:Warning(1,60);assert(e.rows[1].shown and not e.rows[1].done and e.rows[2].shown)
assert(e.rows[1].eventCount==2)
''')

    def test_bar_identity_pause_cancel_finish_and_batch_phase_coexist(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
local p={kind='events',specID=251,encounterID=3105,difficulty='mythic',enabled=true,
rows={{id=1,spellID=51271,anchor='dog',occurrence=1,time=0,window=10,hold='等放狗'}}}
local e=NR.Engine.New();e:Begin(3105,'mythic',nil,{},0,{specID=251},p)
e:Timeline('snapshot',{id=90,source=0,duration=10},0)
e:Timeline('added',{id=1,source=0,duration=10},0);assert(not e.rows[1].target)
e:Timeline('added',{id=2,source=0,duration=15},.1)
e:Timeline('added',{id=3,source=0,duration=24},.2);assert(e.rows[1].target==10)
e:Tick(5);assert(e.rows[1].shown)
e:Timeline('paused',{id=1},6);assert(not e.rows[1].shown and not e.rows[1].target and e.rows[1].held)
e:Tick(30);assert(not e.rows[1].shown)
e:Timeline('finished',{id=1},35);assert(e.rows[1].target==35 and e.rows[1].shown)
e:Cast(51271,35);e:Timeline('finished',{id=1},36);assert(e.rows[1].done)
e:Begin(3105,'mythic',nil,{},0,{specID=251},p)
for i,d in ipairs({10,15,24}) do e:Timeline('added',{id=i,source=0,duration=d},0) end
e:Tick(5);e:Timeline('canceled',{id=1},6);assert(not e.rows[1].target and e.rows[1].held)
e:Timeline('removed',{id=1},6.1);assert(e.bossEvents.counts.dog==0)
for i,d in ipairs({10,15,24}) do e:Timeline('added',{id=i+10,source=0,duration=d},10) end
assert(e.rows[1].target==20 and e.bossEvents.counts.dog==1)
e:Begin(3105,'mythic',nil,{},0,{specID=251},p)
for i,d in ipairs({10,10,15,24}) do e:Timeline('added',{id=i,source=0,duration=d},0) end
assert(not e.rows[1].target)
e:Begin(3457,'mythic',nil,{},0,{})
e:Timeline('added',{id=1,source=0,duration=10},6);e:Timeline('added',{id=2,source=0,duration=25},6.1)
assert(e.sequence==2 and e.bossEvents.counts.p2==1)
''')

    def test_own_note_real_ui_main_preview_and_no_upstream_dependency(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
function GetSpecialization() return 3 end
function GetSpecializationInfo() return 252 end
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
local text='NRPlan:1;EncounterID:3101;Difficulty:mythic;SpecID:252;Name:Test;\nanchor:vuln;occurrence:1;time:0;window:10;spellid:42650;hold:Wait;'
NR.UI.note:SetText(text);NR.UI:Parse();assert(NR.UI.preview.kind=='events')
local settings=NR.Copy(NR.db.settings);NR.UI:Save();assert(NR.EventPlans.Get(252,3101,'mythic'))
assert(NR.db.settings.lead==settings.lead and NR.db.settings.glow==settings.glow)
NR.PreviewUI.referenceEvents=false
assert(NR.PreviewUI:Open(NR.UI.preview));assert(NR.preview.engine.rows[1].held)
assert(NR.preview:Event('vuln',0));assert(NR.preview.engine.rows[1].target==1.7)
NR.preview:Seek(0,0);assert(NR.preview.engine.rows[1].target==1.7)
NR.preview:UseRow('event:1',0);assert(NR.preview.engine.rows[1].done)
NR.preview:Seek(0,0);assert(NR.preview.engine.rows[1].done)
NR.preview:Stop();now=100
driver.scripts.OnEvent(driver,'ENCOUNTER_START',3101,'',8)
local warning=setmetatable({severity=1},{__index=function() error('secret warning field read') end})
now=130;driver.scripts.OnEvent(driver,'ENCOUNTER_WARNING',warning)
assert(NR.engine.rows[1].target==131.7 and NR.engine.rows[1].shown)
driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',42650);assert(NR.engine.rows[1].done)
driver.scripts.OnEvent(driver,'ENCOUNTER_END');assert(not NR.engine.active)
combat=true;NR.UI:Save();assert(NR.EventPlans.Get(252,3101,'mythic'))
''')

    def test_item_slot_public_use_spell_and_text_expiry(self):
        lua,nr=runtime();lua.globals().NR=nr
        lua.execute(r'''
C_Item={GetItemInfo=function() return 'Potion',nil,nil,nil,nil,nil,nil,nil,nil,42 end,GetItemSpell=function() return 'Use',100 end}
function GetInventoryItemID() return 99 end
local p=NR.EventPlans.New(252,3101)
p.rows={{id=1,actionType='slot',slot=13,anchor='start',occurrence=1,time=0,window=10},
{id=2,actionType='text',label='药水与饰品',anchor='start',occurrence=1,time=0,window=10}}
local e=NR.Engine.New();e:Begin(3101,'mythic',nil,{},0,{specID=252},p)
assert(e.rows[1].actionName=='Potion' and e.rows[1].useSpellID==100)
e:Cast(100,1);assert(e.rows[1].done and not e.rows[2].done);e:Tick(10);assert(e.rows[2].done)
C_Item.GetItemSpell=function()return 'Use',{secret=true}end
e:Begin(3101,'mythic',nil,{},0,{specID=252},p);assert(not e.rows[1].useSpellID)
e:Cast({secret=true},1);assert(not e.rows[1].done)
''')

    def test_themed_tabs_preserve_import_and_settings_use_real_save_path(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
local ui=NR.UI
local text="EncounterID:3492;Difficulty:Mythic;\nph:1;time:145.5;spellid:51271;"
ui.note:SetText(text); ui:Parse()
local plan=ui.preview
ui.settingsTab.scripts.OnClick()
assert(ui.page=="settings" and ui.settingsPage:IsShown() and not ui.importPage:IsShown())
assert(ui.settingsTab.themeSelected and not ui.importTab.themeSelected)
assert(ui.volume==nil and ui.glow==nil and ui.checks.tts==nil,'no volume, glow or spell-voice controls')
ui.lead:SetText("7"); ui.window:SetText("8")
for _,key in ipairs({"hideOnUse","countdown","sound"}) do ui.checks[key]:SetChecked(true) end
ui.saveSettings.scripts.OnClick()
assert(NR.db.settings.lead==7 and NR.db.settings.window==8)
combat=true; ui.lead:SetText("9"); ui.saveSettings.scripts.OnClick(); assert(NR.db.settings.lead==7)
combat=false; ui.importTab.scripts.OnClick()
assert(ui.note:GetText()==text and ui.preview==plan and ui.importPage:IsShown() and not ui.settingsPage:IsShown())
ui.saveButton.scripts.OnClick(); assert(NR.NotePlans(251).plans["3492:mythic"].enabled)
ui.note:SetText("bad"); ui:Parse(); assert(not ui.bindingScroll:IsShown() and not ui.bindingTitle:IsShown())
''')

    def test_preview_respects_existing_node_order_and_shared_bindings(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local plan=NR.ParseNote("EncounterID:3101;Difficulty:Mythic;\nph:2;time:3;spellid:51271;\nph:3;time:4;spellid:152279;\nph:4;time:5;spellid:51271;")
plan.phaseBindings[2]=5; plan.phaseBindings[3]=2; plan.phaseBindings[4]=2
assert(NR.ValidateBindings(plan))
local p=NR.Preview.New(function() end); assert(p:Start(plan,{}, {},0))
assert(p:NextPhase(0)); assert(not p.engine.rows[1].target)
assert(p.engine.rows[2].target==4 and p.engine.rows[3].target==5)
assert(p:NextPhase(0)); assert(p.engine.rows[1].target==3)
assert(plan.phaseBindings[2]==5 and plan.phaseBindings[3]==2 and plan.phaseBindings[4]==2)
''')

    def test_preview_seek_pause_speed_and_backward_restore(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:135.5;spellid:51271;\nph:1;time:300;spellid:152279;")
local events={}; local clears=0
local p=NR.Preview.New(function(kind,row,value) events[#events+1]={kind=kind,value=value,id=type(row)=="table" and row.id} end,function() clears=clears+1 end)
assert(p:Start(plan,{}, {},1000)); assert(p.running and p.playing)
assert(p:Seek(130.5,1000)); assert(p.engine.rows[1].shown and p.engine.rows[1].target==135.5)
p:Pause(1000); p:Tick(1500); assert(p.position==130.5 and not p.playing)
assert(p:Resume(1500)); p:Tick(1502); assert(p.position==132.5)
local found=false
for _, event in ipairs(events) do if event.kind=="countdown" and event.value==3 then found=true end end
assert(found)
assert(p:SetSpeed(2,1502)); p:Tick(1503); assert(p.position==134.5)
p:Cast(51271,1503); assert(p.engine.rows[1].done and not p.engine.rows[2].done)
assert(p:Seek(125,1503)); assert(not p.engine.rows[1].shown and not p.engine.rows[1].done and #p.actions==0)
assert(not p:Seek(-1,1503)); assert(not p:SetSpeed(99,1503))
assert(plan.rows[1].time==135.5 and not plan.rows[1].shown and not plan.enabled)
p:Stop(); assert(not p.running and not p.engine.active and clears>0)
''')

    def test_unbound_raid_preview_is_manual_and_does_not_enable_live_plan(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local plan=NR.ParseNote("EncounterID:9999;Difficulty:Heroic;\nph:1;time:300;spellid:51271;\nph:2;time:3;spellid:152279;\nph:3;time:5;spellid:51271;")
assert(not NR.ValidateBindings(plan))
local p=NR.Preview.New(function() end)
assert(p:Start(plan,{}, {},0)); assert(not p.engine.rows[2].target)
assert(p:Seek(100,0)); p:Pause(0)
assert(p:NextPhase(0)); assert(p.position==100 and p.engine.rows[2].target==103 and p.engine.rows[2].shown)
p:Cast(152279,0); assert(p.engine.rows[2].done)
assert(p:Seek(110,0)); assert(p.engine.rows[2].done and p.engine.rows[2].target==103)
assert(p:NextPhase(0)); assert(p.engine.rows[3].target==115)
assert(p:Seek(90,0)); assert(p.engine.sequence==1 and #p.actions==0 and not p.engine.rows[2].target)
assert(not plan.phaseBindings[2] and not plan.phaseBindings[3] and not NR.ValidateBindings(plan))
assert(not NR.BossData.encounters[9999], "preview must not modify the live boss catalog")
plan.enabled=true
local live=NR.Engine.New(); live:Begin(9999,"heroic",plan,{},0,{})
assert(#live.rows==0, "manual rehearsal must not silently enable an unsupported raid phase")
''')

    def test_preview_ui_full_plan_and_real_encounter_takeover(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]; driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
local text="EncounterID:3492;Difficulty:Heroic;\nph:1;time:135.5;spellid:51271;\nph:1;time:300;spellid:152279;"
NR.UI.note:SetText(text); NR.UI:Parse(); NR.UI:Save()
local saved=NR.NotePlans(251).plans["3492:heroic"]
NR.UI.playPreview.scripts.OnClick(); assert(NR.PreviewUI.frame:IsShown() and NR.preview.running)
assert(not NR.engine.active and #NR.engine.trace==0)
assert(NR.preview:Seek(130.5,now));NR.PreviewUI:Update()
assert(NR.Display.rows[1].label:GetText():find("预览",1,true))
assert(NR.Display.previewMode and NR.Display.container.point[1]=="TOP")
NR.PreviewUI.rows[1].use.scripts.OnClick(); assert(NR.preview.engine.rows[1].done)
assert(NR.NotePlans(251).plans["3492:heroic"]==saved and saved.rows[1].time==135.5 and not saved.rows[1].done)
now=1000; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
assert(not NR.preview.running and not NR.PreviewUI.frame:IsShown() and NR.engine.active)
assert(not NR.Display.previewMode and NR.Display.container.point[1]=="TOP" and NR.Display.container.point[5]==-144,"live rows: 16% down from the top")
assert(NR.engine.rows[1].target==1135.5 and not NR.engine.rows[1].done)
now=1130.5; driver.scripts.OnUpdate(driver,0.1)
assert(NR.engine.rows[1].shown and not NR.Display.rows[1].label:GetText():find("预览",1,true))
NR.preview:Stop(); assert(NR.Display.rows[1]:IsShown(), "stopping an inactive preview must not clear live reminders")
driver.scripts.OnEvent(driver,"ENCOUNTER_END")
SlashCmdList.NEXTREMINDERS("preview"); assert(NR.preview.running)
combat=true; driver.scripts.OnEvent(driver,"PLAYER_REGEN_DISABLED")
assert(not NR.preview.running and not NR.Display.rows[1]:IsShown() and not NR.PreviewUI.frame:IsShown())
assert(not NR.PreviewUI:Open(saved))
''')

    def test_preview_ui_stale_import_close_and_large_scroll_list(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
local text="EncounterID:9999;Difficulty:Heroic;\nph:2;time:3;spellid:152279;"
NR.UI.note:SetText(text); NR.UI:Parse(); NR.UI.note:SetText(text.."\n")
NR.UI:Play(); assert(not NR.preview.running)
NR.UI:Parse(); NR.UI:Play(); assert(NR.preview.running)
NR.PreviewUI.phase.scripts.OnClick(); assert(NR.preview.position==15 and NR.preview.engine.rows[1].target==18)
NR.PreviewUI.frame:Hide(); assert(not NR.preview.running and not NR.Display.rows[1]:IsShown())
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:0;spellid:51271;")
for i=2,500 do plan.rows[i]={id=i,phase=1,time=i,spellID=51271,tag="player"} end
assert(NR.PreviewUI:Open(plan)); assert(#NR.PreviewUI.rows==500 and NR.PreviewUI.rows[500]:IsShown())
NR.PreviewUI.frame:Hide()
local small=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;")
assert(NR.PreviewUI:Open(small)); assert(not NR.PreviewUI.rows[500]:IsShown())
NR.PreviewUI.frame:Hide()
local multi="EncounterID:9999;Difficulty:Heroic;\n"
for i=2,10 do multi=multi.."ph:"..i..";time:3;spellid:51271;\n" end
NR.UI.note:SetText(multi); NR.UI:Parse(); NR.UI:Play()
assert(NR.preview.running and #NR.preview.engine.rows==9)
assert(#NR.UI.binders==9 and NR.UI.bindingContent:GetHeight()==360)
NR.UI:Save(); assert(not NR.NotePlans(251).plans["9999:heroic"])
''')

    def test_preview_finishes_and_restarts_without_saved_changes(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:5;spellid:51271;")
assert(NR.PreviewUI:Open(plan))
now=60; created[1].scripts.OnUpdate(created[1],0.1)
assert(NR.preview.running and not NR.preview.playing and NR.preview.status=="播放结束")
assert(not NR.Display.rows[1]:IsShown())
NR.PreviewUI.play.scripts.OnClick(); assert(NR.preview.running and NR.preview.position==0)
assert(NR.Display.rows[1]:IsShown())
NR.PreviewUI.frame:Hide(); assert(not NR.preview.running and not NR.Display.rows[1]:IsShown())
assert(next(NR.NotePlans(251).plans)==nil)
''')

    def test_independent_boss_data_contract(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local data=NR.BossData
assert(data.schema==1 and type(data.dataVersion)=="string" and data.dataVersion:match("^%d+%.%d+%.%d+%.%d+$"))
assert(not data.archiveSHA256 and not data.sourceVersion)
local function integer(v,low,high) return NR.Number(v,low,high) and v%1==0 end
for id, definition in pairs(data.encounters) do
 assert(integer(id,1,1000000) and type(definition.name)=="string" and #definition.name>0)
 assert(NR.Number(definition.guard,0,60) and type(definition.anchors)=="table" and type(definition.rules)=="table")
 for anchor,name in pairs(definition.anchors) do assert(integer(anchor,2,100) and type(name)=="string" and #name>0) end
 for _,rule in ipairs(definition.rules) do
  assert(rule.added or rule.canceled or rule.durations, "empty rules would match every event")
  if rule.added then assert(integer(rule.added,1,100)) end
  if rule.canceled then assert(integer(rule.canceled,1,100)) end
  if rule.logicalPhase then assert(integer(rule.logicalPhase,1,100)) end
  if rule.nextLogicalPhase then assert(integer(rule.nextLogicalPhase,1,100)) end
  if rule.durations then
   assert(type(rule.durations)=="table" and #rule.durations>0)
   for _,duration in ipairs(rule.durations) do assert(NR.Number(duration,0.001,3600)) end
  end
 end
 for _,fixed in ipairs(definition.fixed or {}) do
  assert(integer(fixed.spellID,1,10000000) and type(fixed.name)=="string")
  local count=0
  for _,key in ipairs({"times","timesHeroic","timesMythic"}) do
   if fixed[key] then
    count=count+1; local previous=-1; assert(#fixed[key]>0)
    for _,time in ipairs(fixed[key]) do assert(NR.Number(time,0,3600) and time>previous); previous=time end
   end
  end
  assert(count>0)
  if fixed.castDuration then assert(NR.Number(fixed.castDuration,0.001,3600)) end
  if fixed.window then assert(NR.Number(fixed.window,0.001,3600)) end
 end
end
''')

    def test_mythic_source_can_target_heroic_without_changing_times(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local note="EncounterID:3492;Difficulty:Mythic;Name:Ulatek;\nph:1;time:145.5;tag:TopPlayer;spellid:51271;"
local original=NR.ParseNote(note)
local heroic=NR.ParseNote(note,{targetDifficulty="heroic"})
assert(heroic.difficulty=="heroic" and heroic.sourceDifficulty=="mythic")
assert(heroic.rows[1].time==original.rows[1].time and original.difficulty=="mythic")
assert(NR.ValidateBindings(heroic))
assert(not NR.ParseNote(note,{targetDifficulty="invalid"}))
assert(not NR.ParseNote(note:gsub("Difficulty:Mythic","Difficulty:invalid"),{targetDifficulty="heroic"}))
local staged=NR.ParseNote("EncounterID:3101;Difficulty:Mythic;\nph:2;time:5;spellid:152279;",{targetDifficulty="heroic"})
staged.phaseBindings[2]=2; assert(not NR.ValidateBindings(staged))
staged.phaseBindings[2]="pull"; assert(NR.ValidateBindings(staged))
''')

    def test_ui_cross_difficulty_import_activates_only_selected_difficulty(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]; driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
local note="EncounterID:3492;Difficulty:Mythic;\nph:1;time:145.5;spellid:51271;"
NR.UI.note:SetText(note); NR.UI:Parse(); NR.UI:Save()
local original=NR.NotePlans(251).plans["3492:mythic"]
NR.UI.difficultyButton.scripts.OnClick(NR.UI.difficultyButton)
assert(NR.UI.difficulty=="heroic")
NR.UI:Parse(); NR.UI:Save()
assert(NR.NotePlans(251).plans["3492:mythic"]==original)
assert(NR.NotePlans(251).plans["3492:heroic"].sourceDifficulty=="mythic")
assert(NR.UI.summary:GetText():find("来源",1,true))
now=100; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
assert(#NR.engine.rows==1 and NR.engine.rows[1].target==245.5)
now=240.5; driver.scripts.OnUpdate(driver,0.1); assert(NR.engine.rows[1].shown)
driver.scripts.OnEvent(driver,"ENCOUNTER_END")
driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",14)
assert(#NR.engine.rows==0)
NR.UI:Parse(); NR.UI.difficulty="normal"; NR.UI:Save()
assert(not NR.NotePlans(251).plans["3492:normal"])
''')

    def test_demo_command_uses_real_scheduler_and_cleans_up(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]
driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
now=100; SlashCmdList.NEXTREMINDERS("test")
assert(NR.preview.running and #NR.preview.engine.rows==1 and NR.preview.engine.rows[1].shown)
assert(not NR.engine.active and #NR.engine.trace==0, "demo must not alter the live engine")
assert(NR.Display.rows[1]:IsShown() and #voiceCalls==0,'nothing is spoken when a reminder shows')
assert(next(NR.NotePlans(251).plans)==nil, "demo must not create a saved boss plan")
now=103.7; driver.scripts.OnUpdate(driver,0.1); assert(NR.preview.engine.rows[1].lastCountdown=="prepare")
now=107.1; driver.scripts.OnUpdate(driver,0.1); assert(NR.preview.engine.rows[1].lastCountdown==3)
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",{secret=true})
assert(not NR.preview.engine.rows[1].done)
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",51271)
assert(NR.preview.engine.rows[1].done and not NR.Display.rows[1]:IsShown())
SlashCmdList.NEXTREMINDERS("stop"); assert(not NR.preview.running and not NR.engine.active)
SlashCmdList.NEXTREMINDERS("test"); now=128; driver.scripts.OnUpdate(driver,0.1)
assert(not NR.preview.running and not NR.Display.rows[1]:IsShown())
combat=true; SlashCmdList.NEXTREMINDERS("test"); assert(not NR.preview.running and not NR.engine.active)
''')

    def test_ui_multiple_bindings_and_control_reuse(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
NR.UI.note:SetText("EncounterID:3101;Difficulty:Mythic;\nph:2;time:5;spellid:152279;\nph:3;time:4;spellid:51271;")
NR.UI:Parse()
local a,b=NR.UI.binders[1],NR.UI.binders[2]
a.scripts.OnClick(a); a.scripts.OnClick(a)
b.scripts.OnClick(b); b.scripts.OnClick(b); b.scripts.OnClick(b)
assert(NR.UI.preview.phaseBindings[2]==2 and NR.UI.preview.phaseBindings[3]==3)
NR.UI:Save(); assert(NR.NotePlans(251).plans["3101:mythic"].phaseBindings[3]==3)
local count=#created; NR.UI:Parse()
assert(#created==count and NR.UI.binders[1]==a and NR.UI.binders[2]==b)
assert(not NR.UI.preview.phaseBindings[2] and not NR.UI.preview.phaseBindings[3])
NR.UI.personal:SetChecked(false); NR.UI:Refresh(); assert(not NR.UI.personal:GetChecked())
''')

    def test_team_tags_match_lorrgs_spec_exports(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local e=NR.Engine.New(); e.identity={name="leslie",fullName="leslie-realm",class="deathknight",specID=251,specIndex=2,role="damager",group=3}
assert(e:TagMatches("spec:DEATHKNIGHT:2") and e:TagMatches("251"))
assert(e:TagMatches("Leslie-Realm") and e:TagMatches("group3"))
assert(not e:TagMatches("spec:DEATHKNIGHT:1") and not e:TagMatches("OtherPlayer"))
''')

    def test_existing_public_timers_seed_cancellation_without_phase_signal(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]; driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
C_EncounterTimeline.GetEventList=function() return {1,2,3,4} end
C_EncounterTimeline.GetEventInfo=function(id) return {source=id==3 and 1 or 0,spellID={secret=true}} end
Enum.EncounterTimelineEventState.Finished=4
C_EncounterTimeline.GetEventState=function(id) return id==4 and 4 or 0 end
driver.scripts.OnEvent(driver,"ENCOUNTER_START",3101,"Kystia",8)
assert(NR.engine.sequence==1 and #NR.engine.added==0)
assert(NR.engine.events[1] and NR.engine.events[2] and not NR.engine.events[4])
C_EncounterTimeline.GetEventState=function() return 3 end
now=10; driver.scripts.OnEvent(driver,"ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",3)
assert(#NR.engine.canceled==0)
driver.scripts.OnEvent(driver,"ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",1)
now=10.1; driver.scripts.OnEvent(driver,"ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",2)
assert(NR.engine.sequence==2 and NR.engine.logicalPhase==2)
''')

    def test_static_all_lua51(self):
        lua = LuaRuntime()
        for path in ADDON.glob("*.lua"):
            lua.execute("assert(loadstring(...))",path.read_text(encoding="utf-8"))

    def test_nsrt_and_mrt_and_no_execution(self):
        lua,nr=runtime()
        lua.globals().NR=nr
        lua.execute(r'''
local note="EncounterID:3492;Difficulty:Heroic;Name:Ulatek;\nph:1;time:135.5;tag:TopPlayer;spellid:51271;"
local p,e=NR.ParseNote(note)
assert(p and not e and p.personal and p.rows[1].time==135.5)
assert(NR.ValidateBindings(p))
local q=NR.ParseNote(note.."\nph:1;time:135.5;tag:TopPlayer;spellid:51271;")
assert(#q.rows==1)
local d=NR.ParseNote("EncounterID:3101;Difficulty:Mythic;\nph:2;time:5;spellid:152279;")
assert(d and not NR.ValidateBindings(d))
d.phaseBindings[2]=2; assert(NR.ValidateBindings(d))
local unknown=NR.ParseNote("EncounterID:9999;Difficulty:Mythic;\nph:2;time:5;spellid:152279;")
unknown.phaseBindings[2]=2; assert(not NR.ValidateBindings(unknown))
unknown.phaseBindings[2]="pull"; assert(NR.ValidateBindings(unknown))
local wrongDifficulty=NR.ParseNote("EncounterID:3101;Difficulty:Heroic;\nph:2;time:5;spellid:152279;")
wrongDifficulty.phaseBindings[2]=2; assert(not NR.ValidateBindings(wrongDifficulty))
local m=NR.ParseNote("{time:02:15.5} - TopPlayer {spell:51271}",{encounterID=3492,difficulty="heroic"})
assert(m and m.rows[1].time==135.5)
local mp=NR.ParseNote("{time:00:03,p2} - X {spell:51271}",{encounterID=3101})
assert(mp and mp.rows[1].phase==2 and mp.rows[1].time==3)
assert(not NR.ParseNote("os.execute('bad')"))
assert(not NR.ParseNote(note.."\nph:1;time:0;time:2;spellid:51271;"))
assert(not NR.ParseNote(note.."\nph:1;time:-1;spellid:51271;"))
assert(not NR.ParseNote(note.."\nph:1;time:nan;spellid:51271;"))
assert(not NR.ParseNote(note.."\nph:1;time:0;spellid:51271;unknown:x;"))
assert(not NR.ParseNote(note.."\nEncounterID:2125;Difficulty:Mythic;"))
assert(not NR.ParseNote(note.."\nph:1;time:2;spellid:51271;invalid"))
assert(not NR.ParseNote(note.."\nph:broken;time:2;spellid:51271;"))
assert(not NR.ParseNote("EncounterID:3492;Difficulty:Heroic;Unknown:1;\nph:1;time:1;spellid:51271;"))
assert(not NR.ValidateBindings({encounterID=3101}))
p.rows[1].time=-1; assert(not NR.ValidateBindings(p))
''')

    def test_timers_use_hide_and_future_casts(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local events={}
local e=NR.Engine.New(function(kind,row) events[#events+1]={kind=kind,id=type(row)=="table" and row.id} end)
local p=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;\nph:1;time:70;spellid:51271;")
p.enabled=true
e:Begin(3492,"heroic",p,{lead=5,window=10,countdown=false},0,{})
e:Cast(51271,1); assert(not e.rows[1].done and not e.rows[2].done)
e:Tick(5); assert(e.rows[1].shown)
e:Cast(51271,6); assert(e.rows[1].done and not e.rows[2].done)
e:Tick(8); assert(not e.rows[1].shown)
e:Tick(65); assert(e.rows[2].shown)
e:Tick(80.1); assert(e.rows[2].done)
e:Stop(); assert(not e.active)
e:Begin(3492,"mythic",p,{},0,{}); assert(#e.rows==0)
''')

    def test_public_phase_detection_and_filters(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local e=NR.Engine.New()
e:Begin(3101,"mythic",nil,{},0,{})
e:Timeline("added",{id=1,source=0,duration=20},1)
e:Timeline("added",{id=2,source=0,duration=30},1)
e:Timeline("canceled",{id=1},10)
e:Timeline("canceled",{id=1},10.1); assert(e.sequence==1)
e:Timeline("canceled",{id=2},10.2); assert(e.sequence==2 and e.logicalPhase==2)
e:Timeline("added",{id=3,source=0,duration=1},15.3)
e:Timeline("added",{id=4,source=0,duration=1},15.4)
e:Timeline("added",{id=5,source=0,duration=1},15.5); assert(e.sequence==3)
e:Begin(3457,"mythic",nil,{},0,{})
e:Timeline("added",{id=1,source=1,duration=25},10)
e:Timeline("added",{id=2,source=0,duration=10},10.1); assert(e.sequence==1)
e:Timeline("added",{id=3,source=0,duration=25},10.2); assert(e.sequence==2)
e:Begin(3457,"mythic",nil,{},0,{})
e:Timeline("added",{id=1,source=0,duration={secret=true}},10)
e:Timeline("added",{id=2,source=0,duration=10},10.1); assert(e.sequence==1)
e:Timeline("added",{id={secret=true},source=0,duration=25},10.2); assert(e.sequence==1)
e:Timeline("added",{id=3,source={secret=true},duration=25},10.2); assert(e.sequence==1)
e:Begin(3208,"mythic",nil,{},0,{})
for i,d in ipairs({50,25,13,7}) do e:Timeline("added",{id=i,source=0,duration=d},10+i*0.03) end
assert(e.sequence==2)
e:Begin(2125,"mythic",nil,{},0,{})
for i=1,5 do e:Timeline("added",{id=i,source=0,duration=i},10+i*0.03) end
assert(e.sequence==2)
e:Begin(2127,"mythic",nil,{},0,{})
e:Timeline("added",{id=1,source=0,duration=15.05},10); assert(e.sequence==2)
e:Timeline("added",{id=2,source=0,duration=32.5},11); assert(e.sequence==2)
e:Timeline("added",{id=3,source=0,duration=32.5},20); assert(e.sequence==3)
''')

    def test_phase_reminders_and_pull_clock(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r'''
local p=NR.ParseNote("EncounterID:3101;Difficulty:Mythic;\nph:1;time:100;spellid:51271;\nph:2;time:5;spellid:152279;\nph:3;time:4;spellid:51271;")
p.enabled=true; p.phaseBindings[2]=2; p.phaseBindings[3]=3
local e=NR.Engine.New(); e:Begin(3101,"mythic",p,{},0,{})
e:Tick(50); assert(not e.rows[2].shown)
e:Transition(80,2); assert(e.rows[2].shown and e.rows[2].target==85)
e:Transition(83,1); assert(e.rows[2].done and e.rows[3].target==87)
e:Tick(95); assert(e.rows[1].shown and e.rows[1].target==100)
''')

    def test_main_ui_import_and_combat_lifecycle(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]
driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
NR.UI.note:SetText("EncounterID:3492;Difficulty:Heroic;\nph:1;time:10;spellid:51271;")
NR.UI:Refresh(); NR.UI:Parse(); NR.UI:Save()
assert(NR.NotePlans(251).plans["3492:heroic"].enabled)
combat=true; NR.UI.note:SetText("bad"); NR.UI:Parse()
assert(NR.NotePlans(251).plans["3492:heroic"].rows[1].time==10)
now=100; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
now=105; driver.scripts.OnUpdate(driver,0.1); assert(NR.engine.rows[1].shown)
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",51271)
assert(NR.engine.rows[1].done)
driver.scripts.OnEvent(driver,"ENCOUNTER_END"); assert(not NR.engine.active)
combat=false
NR.UI.note:SetText("{time:00:10} - X {spell:51271}"); NR.UI.encounter:SetText("3492"); NR.UI:Parse()
NR.UI.encounter:SetText("3105"); NR.UI:Save(); assert(not NR.NotePlans(251).plans["3105:mythic"])
''')

    def test_wcl_tool_output_imports_as_pull_relative_plan(self):
        import subprocess
        script = r'''
import {selectSpells, formatNote} from './tools/wcl_note.mjs';
const casts = [{spellID:51271,time:3.24},{spellID:49020,time:4.1},{spellID:49020,time:5.3},{spellID:51271,time:90.3},
  {spellID:47528,time:18.4},{spellID:47528,time:134.8}];
const {keep} = selectSpells(casts, {exclude:[47528], minGap:45});
process.stdout.write(formatNote({encounterID:3101, difficulty:'Mythic', bossName:"Kystia; Manaheart", player:'Xmda Y',
  casts, keep, source:'WCL test'}));
'''
        note = subprocess.run(["node","--input-type=module","-e",script],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",check=True).stdout
        lua,nr=runtime(); lua.globals().NR=nr; lua.globals().note=note
        lua.execute(r'''
local plan=assert(NR.ParseNote(note))
assert(plan.encounterID==3101 and plan.difficulty=="mythic" and plan.format=="NSRT" and #plan.rows==2)
assert(plan.rows[1].time==3.2 and plan.rows[1].spellID==51271 and plan.rows[1].tag=="XmdaY")
assert(plan.rows[2].time==90.3 and NR.ValidateBindings(plan))
''')

    def test_import_flow_gates_actions_on_checked_text_and_sub_page_navigation(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
local ui=NR.UI; ui.frame:Show()
assert(ui.status.text:GetText()=="待检查" and not ui.saveButton.themeEnabled and not ui.playPreview.themeEnabled)
assert(not ui.noteOptions:IsShown(),"empty box shows no Lorrgs options")
local text="EncounterID:3492;Difficulty:Mythic;\nph:1;time:20;spellid:51271;"
ui.note:SetText(text); ui.note.scripts.OnTextChanged(ui.note)
assert(ui.noteOptions:IsShown() and ui.formatLabel:GetText():find("Lorrgs"))
ui.checkButton.scripts.OnClick()
assert(ui.status.text:GetText()=="检查通过" and ui.saveButton.themeEnabled and ui.playPreview.themeEnabled)
ui.note:SetText(text.."\nph:1;time:30;spellid:51271;"); ui.note.scripts.OnTextChanged(ui.note)
assert(ui.status.text:GetText()=="需重新检查" and not ui.saveButton.themeEnabled and not ui.playPreview.themeEnabled)
ui:Parse(); ui.saveButton.scripts.OnClick()
assert(NR.NotePlans(251).plans["3492:mythic"].enabled and ui.status.text:GetText()=="已保存并启用")
assert(not ui.saveButton.themeEnabled,"saving the same check twice would overwrite the backup with itself")
ui.note:SetText("bad"); ui:Parse(); assert(ui.status.text:GetText()=="未通过")
ui.note:SetText("NRDungeon:x"); ui.note.scripts.OnTextChanged(ui.note); assert(not ui.noteOptions:IsShown())
ui.note:SetText(""); ui.note.scripts.OnTextChanged(ui.note); assert(ui.status.text:GetText()=="待检查")
ui:SetPage("settings"); ui.lead:SetText("9"); ui.lead.scripts.OnTextChanged(ui.lead,true)
assert(ui.message:GetText():find("未保存"))
ui.burstButton.scripts.OnClick()
assert(not ui.tabs:IsShown() and not ui.settingsPage:IsShown() and NR.BurstUI.frame:IsShown())
NR.BurstUI.backButton.scripts.OnClick()
assert(ui.tabs:IsShown() and ui.settingsPage:IsShown() and ui.lead:GetText()=="9")
ui.saveSettings.scripts.OnClick(); assert(NR.db.settings.lead==9 and not ui.settingsDirty)
ui.burstButton.scripts.OnClick(); ui.frame:Hide(); ui.frame:Show()
assert(not NR.BurstUI.frame:IsShown() and ui.tabs:IsShown() and ui.settingsPage:IsShown(),"closing on a sub page reopens a usable page")
assert(NR.PreviewUI:OpenLibrary()); ui.enableButton.scripts.OnClick()
assert(NR.db.enabled==false and ui.switches[2]:GetText()=="提醒已停用","both windows show the same master switch")
''')

    def test_text_is_not_covered_by_sibling_panels(self):
        # A child frame with a backdrop draws over its parent's font strings (0.1.3 settings page showed blank panels).
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
NR.UI.frame:Show(); NR.UI:SetPage("settings")
local covered,surfaces={},0
for _,panel in ipairs(created) do
 local p=panel.point
 if rawget(panel,"isSurface") then surfaces=surfaces+1 end
 if rawget(panel,"isSurface") and panel.parent and p and p[1]=="TOPLEFT" and type(p[2])=="number" then
  for _,text in ipairs(fontStrings) do
   local q=text.point
   if text.owner==panel.parent and q and q[1]=="TOPLEFT" and type(q[2])=="number"
    and q[2]>=p[2] and q[2]<p[2]+panel.width and q[3]<=p[3] and q[3]>p[3]-panel.height then
    covered[#covered+1]=tostring(text.text).."@"..q[2]..","..q[3]
   end
  end
 end
end
assert(#covered==0,"text under a panel: "..table.concat(covered," | "))
assert(surfaces>=12,"the cards are checked")
assert(NR.UI.message.text:find("保存设置"),"settings page shows its own hint")
NR.UI:SetPage("import"); assert(NR.UI.message.text:find("Lorrgs"))
''')


    def test_preview_timeline_click_seeks_and_reminder_bar_stays_see_through(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1];driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:5;spellid:51271;\nph:1;time:100;spellid:47568;")
now=0;local ok,err=NR.PreviewUI:Open(plan);assert(ok,tostring(err));NR.preview:Stop();NR.PreviewUI.lastUpdate=nil;NR.PreviewUI:Update()
local tl=NR.PreviewUI.timeline;assert(NR.PreviewUI.span==115,tostring(NR.PreviewUI.span))
tl.GetLeft=function()return 100 end;tl.GetEffectiveScale=function()return 1 end
GetCursorPosition=function()return 100+24+748/2,0 end
tl.scripts.OnMouseDown(tl,"LeftButton")
assert(NR.preview.running and math.abs(NR.preview.position-57.5)<0.1,tostring(NR.preview.running)..' '..tostring(NR.preview.position)..' '..tostring(NR.PreviewUI.message:GetText()))
local row=NR.Display:Row(99);assert(row.backdropColor[4]<=0.2 and not rawget(row,"nrFill"),'reminder bar keeps the old see-through look')
''')

    def test_cleanup_stops_voice_and_waits_for_combat_without_forcing_gc(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local stopped={}
collectgarbage=function() error("must not force garbage collection") end
UpdateAddOnMemoryUsage=function() error("must not scan addon memory") end
StopSound=function(h) stopped[#stopped+1]=h end
PlaySoundFile=function() return true,77 end
local driver=created[1];driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
NR.db.settings=NR.Settings({sound=true})
now=10;NR.Display:Emit("show",{id=1,spellID=42650,target=10},0)
-- Closing the window stops the clip that is still playing without forcing garbage collection.
NR.UI.frame:Show();NR.UI.frame:Hide()
assert(stopped[1]==77 and #stopped==1 and NR.lastCleanup=="close")
assert(not NR.Display.rows[1]:IsShown())
-- In combat it waits, then runs once combat ends.
combat=true;local ok,err=NR.Cleanup("close");assert(not ok and err:find("脱战"))
combat=false;driver.scripts.OnEvent(driver,"PLAYER_REGEN_ENABLED");assert(not NR.cleanupPending)
-- Fight end: cleaned when it is already out of combat; a rehearsal in progress is left alone.
driver.scripts.OnEvent(driver,"ENCOUNTER_END");assert(NR.lastCleanup=="encounter")
NR.preview.running=true;assert(not NR.Cleanup("close"));NR.preview.running=false
-- Memory controls and memory accounting are removed.
NR.UI.frame:Show();NR.UI:SetPage("settings")
assert(NR.UI.cleanButton==nil and NR.UI.memoryLabel==nil and NR.MemoryKB==nil)
SlashCmdList.NEXTREMINDERS("gc")
''')

    def test_fractional_lorrgs_phases_and_bigwigs_stage_bindings(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r"""
assert(NR.Phase(1.5) and NR.Phase(1.75) and NR.Phase(2) and not NR.Phase(1.333) and not NR.Phase(0.5))
assert(NR.ParseClock("2:15")==135 and NR.ParseClock("135.5")==135.5 and not NR.ParseClock("2:75") and not NR.ParseClock("m:ss"))
assert(NR.Stages.Supports(3492,2) and NR.Stages.Supports(3492,2.5) and NR.Stages.Supports(3492,3))
assert(NR.Stages.Supports(3513,2) and not NR.Stages.Supports(3513,2.5))
local note="EncounterID:3470;Difficulty:Mythic;Name:Nekzali;\nph:1;time:10;tag:everyone;spellid:51271;\nph:1.5;time:3;tag:everyone;spellid:152279;\nph:1.75;time:4;tag:everyone;spellid:51271;\nph:2;time:5;tag:everyone;spellid:152279;"
local p,e=NR.ParseNote(note); assert(p,e)
assert(p.phaseBindings[1]=="pull" and p.phaseBindings[1.5]=="stage" and p.phaseBindings[2]=="stage" and p.phaseBindings[1.75]==false)
assert(not NR.ValidateBindings(p))
p.phaseBindings[1.75]="time"; assert(not NR.ValidateBindings(p))
p.phaseFallback[1.75]=100; assert(NR.ValidateBindings(p))
p.phaseBindings[1.75]="stage"; assert(not NR.ValidateBindings(p), "1.75 has no BigWigs stage")
p.phaseBindings[1.75]="time"
p.phaseFallback[1.333]=5; assert(not NR.ValidateBindings(p)); p.phaseFallback[1.333]=nil
local mp=NR.ParseNote("{time:00:03,p2.5} - X {spell:51271}",{encounterID=3429})
assert(mp and mp.rows[1].phase==2.5 and mp.phaseBindings[2.5]=="stage")
assert(not NR.ParseNote("EncounterID:3470;Difficulty:Mythic;\nph:1.333;time:1;spellid:51271;"))
local heroic=NR.ParseNote(note,{targetDifficulty="heroic"}); heroic.phaseFallback[1.75]=100; heroic.phaseBindings[1.75]="time"
assert(NR.ValidateBindings(heroic), "BigWigs bindings work on every difficulty")
-- Live: BigWigs present, stages anchor source phases and retire earlier ones.
p.enabled=true
local e=NR.Engine.New(function() end); e:Begin(3470,"mythic",p,{lead=5,window=10},0,{})
e:Stage(1,0); assert(e.stageReady)
e:Tick(60); assert(not e.rows[2].target and e.rows[3].target==104)
e:Stage(1.5,80); assert(e.rows[2].target==83 and e.rows[2].shown)
e:Stage(2,90); assert(e.rows[4].target==95 and e.rows[3].done and not e.rows[3].shown)
e:Stage(2,95); assert(e.anchorTimes["stage:2"]==90)
-- No BigWigs: stage rows use the entered transition times after a 5 s grace.
p.phaseFallback[1.5]=70; p.phaseFallback[2]=120
local f=NR.Engine.New(function() end); f:Begin(3470,"mythic",p,{lead=5,window=10},0,{})
f:Tick(1); assert(not f.rows[2].target)
f:Tick(6); assert(f.rows[2].target==73 and f.rows[4].target==125)
-- Order-mapped boss counts every BigWigs change.
local o=NR.ParseNote("EncounterID:3497;Difficulty:Heroic;\nph:2;time:1;tag:everyone;spellid:51271;\nph:3;time:1;tag:everyone;spellid:51271;")
o.enabled=true; assert(o.phaseBindings[2]=="stage" and NR.ValidateBindings(o))
local g=NR.Engine.New(function() end); g:Begin(3497,"heroic",o,{},0,{})
g:Stage(1,0); g:Stage(3,30); g:Stage(1,60)
assert(g.rows[1].target==31 and g.rows[2].target==61)
""")

    def test_every_website_raid_export_is_detected_by_bigwigs_stages(self):
        # tests/fixtures/site-raid-exports.json: one plan per raid boss and difficulty exported by the website's own
        # exportRaidNsrt (tellmenext-web web/raid-plan.mjs), one spell per phase it offers, 5+i s into phase i.
        # Every phase the website offers must bind to BigWigs without typed times, and fire on the SetStage
        # sequence the installed BigWigs modules send (v427.6: Nekzali 1.5/2, CoiledAltar and Ulatek 2/2.5/3,
        # Kithix 2). Bosses without phases on the website are pull-relative.
        plans=json.loads((ROOT/"tests/fixtures/site-raid-exports.json").read_text(encoding="utf-8"))["plans"]
        bigwigs={3470:[1.5,2],3429:[2,2.5,3],3492:[2,2.5,3],3513:[2]}
        lua,nr=runtime(); lua.globals().NR=nr
        check=lua.eval(r"""function(text,difficulty,encounterID,stages,phases)
local p,e=NR.ParseNote(text); assert(p,e)
for i=1,#phases do local ph=phases[i]
  assert(p.phaseBindings[ph]==(ph==1 and "pull" or "stage"), encounterID.." P"..ph.." binding "..tostring(p.phaseBindings[ph]))
end
assert(NR.ValidateBindings(p), encounterID.." needs typed phase times")
p.enabled=true
local eng=NR.Engine.New(function() end); eng:Begin(encounterID,difficulty,p,{lead=5,window=10},0,{specID=251})
eng:Stage(1,0); eng:Tick(1)
local at={[1]=0}
for i=1,#stages do local t=100*i; eng:Stage(stages[i],t); at[stages[i]]=t end
assert(#eng.rows==#phases, encounterID.." rows "..#eng.rows)
for i=1,#phases do local ph=phases[i]; local want=at[ph]+5+(i-1)
  local found=false
  for _,row in ipairs(eng.rows) do if row.phase==ph and row.target==want then found=true end end
  assert(found, encounterID.." "..difficulty.." P"..ph.." expected at "..want)
end
return true end""")
        self.assertEqual(len(plans),20)
        for plan in plans:
            enc=plan["encounterID"]
            self.assertEqual(plan["phases"][1:],bigwigs.get(enc,[]),enc)
            with self.subTest(encounter=enc,difficulty=plan["difficulty"]):
                check(plan["text"],plan["difficulty"],enc,lua.table(*bigwigs.get(enc,[])),lua.table(*plan["phases"]))

    def test_bigwigs_messages_drive_saved_plan_and_ui_time_box(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r"""
local handlers={}
BigWigsLoader={RegisterMessage=function(owner,message,fn) assert(owner~=BigWigsLoader); handlers[message]=fn end}
local driver=created[1]
driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
assert(handlers.BigWigs_SetStage and handlers.BigWigs_OnBossEngage)
NR.UI.note:SetText("EncounterID:3470;Difficulty:Mythic;\nph:1.5;time:3;tag:everyone;spellid:51271;\nph:1.75;time:2;tag:everyone;spellid:152279;")
NR.UI:Parse()
assert(NR.UI.binders[1]:GetText():find("BigWigs") and NR.UI.binders[2]:GetText():find("未绑定"))
NR.UI:Save(); assert(not NR.NotePlans(251).plans["3470:mythic"], "unbound 1.75 must block save")
local box=NR.UI.fallbacks[2]; box:SetText("1:40"); box.scripts.OnTextChanged(box)
assert(NR.UI.preview.phaseBindings[1.75]=="time" and NR.UI.preview.phaseFallback[1.75]==100)
NR.UI:Save(); assert(NR.NotePlans(251).plans["3470:mythic"].phaseFallback[1.75]==100)
local module={GetEncounterID=function() return 3470 end}
local other={GetEncounterID=function() return 9999 end}
now=10; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3470,"Nekzali",16)
handlers.BigWigs_OnBossEngage("BigWigs_OnBossEngage",module); assert(NR.engine.stageReady)
handlers.BigWigs_SetStage("BigWigs_SetStage",other,1.5); assert(not NR.engine.anchorTimes["stage:1.5"])
now=50; handlers.BigWigs_SetStage("BigWigs_SetStage",module,1.5); assert(NR.engine.anchorTimes["stage:1.5"]==50)
assert(NR.engine.rows[1].shown and NR.engine.rows[1].target==53)
assert(NR.engine.rows[2].target==112)
driver.scripts.OnEvent(driver,"ENCOUNTER_END")
NR.UI:Parse(); assert(NR.UI.fallbacks[2]:GetText()=="m:ss")
""")


    def test_panel_back_navigation_preserves_settings_and_origin(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r"""
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local main,preview=NR.UI,NR.PreviewUI
main.frame:Show();main:SetPage('settings');main.lead:SetText('17')
main.burstButton.scripts.OnClick()
assert(NR.BurstUI.backButton:GetText()=='返回提醒设置')
NR.BurstUI.backButton.scripts.OnClick()
assert(not NR.BurstUI.frame:IsShown() and main.page=='settings' and main.lead:GetText()=='17')
assert(main:PageHint():find('即时保存'))
assert(preview:OpenLibrary())
assert(preview.backButton:GetText()=='返回提醒设置' and not main.frame:IsShown())
assert(preview:OpenLibrary(),'refresh library must retain origin')
preview.backButton.scripts.OnClick()
assert(main.frame:IsShown() and main.page=='settings' and main.lead:GetText()=='17')
assert(not preview.frame:IsShown() and not NR.preview.running)
main:SetPage('import');assert(preview:OpenLibrary())
assert(preview.backButton:GetText()=='返回方案导入')
preview.backButton.scripts.OnClick();assert(main.page=='import')
main:SetPage('settings');main.burstButton.scripts.OnClick();main:SetPage('import')
assert(not NR.BurstUI.frame:IsShown(),'changing main page closes child editor')
""")

    def test_import_filters_deleted_default_bursts_for_text_and_preview(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r"""
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI
local text='EncounterID:3492;Difficulty:Mythic;\nph:1;time:10;spellid:51271;\nph:1;time:20;spellid:47568;\nph:1;time:30;spellid:51271;'
ui.note:SetText(text);ui:Parse();assert(#ui.preview.rows==3)
ui:Save();assert(#NR.NotePlans(251).plans['3492:mythic'].rows==3)
assert(NR.BurstSpells.Save(251,{439843}))
assert(#NR.NotePlans(251).plans['3492:mythic'].rows==3,'saved plans are not changed')
ui:Parse();assert(#ui.preview.rows==1 and ui.preview.rows[1].spellID==47568)
ui:Play();assert(#NR.preview.plan.rows==1 and NR.preview.plan.rows[1].spellID==47568)
ui:Save();assert(#NR.NotePlans(251).plans['3492:mythic'].rows==1)
assert(ui.message:GetText():find('已按你的爆发名单跳过 2 条提醒',1,true))
assert(NR.BurstSpells.Save(251,{}))
ui:Parse();assert(#ui.preview.rows==1 and ui.preview.rows[1].spellID==47568)
ui:Save();assert(ui.message:GetText():find('已按你的爆发名单跳过 2 条提醒',1,true))
local mrt='{time:00:10} - player {spell:51271}\n{time:00:20} - player {spell:47568}'
ui.encounter:SetText('3492');ui.note:SetText(mrt);ui:Parse()
assert(#ui.preview.rows==1 and ui.preview.rows[1].spellID==47568)
ui:Save();assert(ui.message:GetText():find('已按你的爆发名单跳过 1 条提醒',1,true))
ui.note:SetText('EncounterID:3492;Difficulty:Mythic;\nph:1;time:10;spellid:51271;')
ui:Parse();assert(not ui.preview);ui:Save()
assert(#NR.NotePlans(251).plans['3492:mythic'].rows==1)
assert(NR.BurstSpells.Reset(251))
ui.note:SetText(text);ui:Parse();assert(#ui.preview.rows==3)
ui:Save();assert(#NR.NotePlans(251).plans['3492:mythic'].rows==3)
""")

    def test_import_filters_dungeon_and_event_actions_atomically(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r"""
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI
local header='NRDungeon:1;DungeonID:2813;Difficulty:mythic;SpecID:252;\n'
local first='NRPlan:2;EncounterID:3101;Difficulty:mythic;SpecID:252;\n'
local second='NRPlan:2;EncounterID:3105;Difficulty:mythic;SpecID:252;\n'
local base='anchor:start;occurrence:1;time:0;window:10;'
local spell=base..'spellid:42650;\n'
local extra=base..'spellid:999991;\n'
local item=base..'itemid:42650;\n'
local slot=base..'slot:13;\n'
local label=base..'text:hello;\n'
local text=header..first..spell..extra..item..slot..label..second..spell..extra
assert(NR.BurstSpells.Save(252,{}))
ui.note:SetText(text);ui:Parse();assert(ui.preview and #ui.preview.plans==2)
assert(#ui.preview.plans[1].rows==4 and #ui.preview.plans[2].rows==1)
ui:Play();assert(#NR.preview.plan.rows==4)
ui:Save();assert(ui.message:GetText():find('已按你的爆发名单跳过 2 条提醒',1,true))
local saved=NR.EventPlans.Get(252,3101,'mythic')
assert(#saved.rows==4 and saved.rows[1].spellID==999991)
assert(saved.rows[2].itemID==42650 and saved.rows[3].slot==13 and saved.rows[4].label=='hello')
assert(NR.EventPlans.Get(252,3105,'mythic').rows[1].spellID==999991)
local previous=NR.db.previousDungeons['252:2813']
ui.note:SetText(header..first..extra..second..spell);ui:Parse()
assert(not ui.preview);ui:Save()
assert(NR.EventPlans.Get(252,3101,'mythic')==saved and NR.db.previousDungeons['252:2813']==previous)
assert(NR.EventPlans.Get(252,3105,'mythic').rows[1].spellID==999991)
ui.note:SetText(first..spell..extra);ui:Parse()
assert(ui.preview and #ui.preview.rows==1 and ui.preview.rows[1].spellID==999991)
ui:Save();assert(ui.message:GetText():find('已按你的爆发名单跳过 1 条提醒',1,true))
assert(#NR.EventPlans.Get(252,3101,'mythic').rows==1)
""")

    def test_import_rechecks_when_burst_list_or_text_target_spec_changes(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r"""
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
local ui=NR.UI
ui.note:SetText('EncounterID:3492;Difficulty:Mythic;\nph:1;time:10;spellid:51271;\nph:1;time:20;spellid:47568;')
ui:Parse();assert(#ui.preview.rows==2)
assert(NR.BurstSpells.Save(251,{}));ui:Play();assert(not NR.preview.running)
ui:Save()
assert(not NR.NotePlans(251).plans['3492:mythic'])
ui:Parse();assert(#ui.preview.rows==1);ui:Save()
assert(#NR.NotePlans(251).plans['3492:mythic'].rows==1)
ui:Parse();function GetSpecializationInfo() return 252 end;ui:Save()
assert(not NR.NotePlans(252).plans['3492:mythic'])
ui:Parse();assert(#ui.preview.rows==2);ui:Save()
assert(#NR.NotePlans(252).plans['3492:mythic'].rows==2)
local event='NRPlan:2;EncounterID:3101;Difficulty:mythic;SpecID:252;\nanchor:start;occurrence:1;time:0;window:10;spellid:42650;\nanchor:start;occurrence:1;time:5;window:10;spellid:999991;'
ui.note:SetText(event);ui:Parse();assert(#ui.preview.rows==2)
assert(NR.BurstSpells.Save(251,{51271}));ui:Save()
assert(#NR.EventPlans.Get(252,3101,'mythic').rows==2,'other spec edits do not invalidate the checked website plan')
ui:Parse();assert(NR.BurstSpells.Save(252,{}));ui:Save()
assert(#NR.EventPlans.Get(252,3101,'mythic').rows==2,'target spec edits must require rechecking')
ui:Parse();ui:Save();assert(#NR.EventPlans.Get(252,3101,'mythic').rows==1)
""")

    def test_custom_burst_list_persistence_empty_reset_and_combat_guards(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r"""
NR.db={}
C_SpellBook={IsSpellKnown=function() return true end}
local initial,custom=NR.BurstSpells.Get(251)
assert(#initial==3 and not custom)
local ids={51271,999991}
assert(NR.BurstSpells.Save(251,ids)); ids[1]=47568
local p=NR.EventPlans.Default(251,9999)
assert(#p.rows==2 and p.rows[1].spellID==51271 and p.rows[2].spellID==999991)
local read=NR.BurstSpells.Get(251);read[1]=47568
assert(NR.BurstSpells.Get(251)[1]==51271,'read/write copies isolate persisted selection')
NR.db=NR.Copy(NR.db)
assert(NR.EventPlans.Default(251,9999).rows[2].spellID==999991,'saved table survives reload')
assert(not select(2,NR.BurstSpells.Get(252)),'other specs keep defaults')
assert(not NR.BurstSpells.Save(251,{51271,51271}))
assert(not NR.BurstSpells.Save(251,{[2]=51271}))
assert(not NR.BurstSpells.Save(251,{0}))
local huge={};for i=1,101 do huge[i]=i end
assert(not NR.BurstSpells.Save(251,huge))
combat=true
assert(not NR.BurstSpells.Save(251,{}));assert(not NR.BurstSpells.Reset(251))
combat=false
assert(#NR.BurstSpells.Get(251)==2)
assert(NR.BurstSpells.Save(251,{}));assert(select(2,NR.BurstSpells.Get(251)))
assert(not NR.EventPlans.Default(251,9999),'explicit empty does not fall back to built-ins')
assert(NR.BurstSpells.Reset(251));assert(#NR.BurstSpells.Get(251)==3)
assert(not select(2,NR.BurstSpells.Get(251)))
assert(NR.BurstSpells.Save(251,{999991,51271}))
C_SpellBook.IsSpellKnown=function(id)return id==51271 end
p=NR.EventPlans.Default(251,9999);assert(#p.rows==1 and p.rows[1].spellID==51271)
C_SpellBook=nil;IsPlayerSpell=nil
p=NR.EventPlans.Default(251,9999);assert(#p.rows==1 and p.rows[1].spellID==51271,'unknown custom spells fail closed')
""")

    def test_custom_burst_ui_add_remove_and_spec_switch(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r"""
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
NR.UI.frame:Show();NR.UI:SetPage('settings')
NR.UI.burstButton.scripts.OnClick()
local u=NR.BurstUI
assert(u.frame:IsShown() and u.specID==251)
assert(#u.selected.rows==3 and u.selected.rows[1].name.owner==u.selected.rows[1])
local removed=u.selected.rows[1].spellID
u.selected.rows[1].button.scripts.OnClick()
assert(#NR.BurstSpells.Get(251)==2 and select(2,NR.BurstSpells.Get(251)))
local found=false
for _,row in ipairs(u.available.rows) do
 if row:IsShown() and row.spellID==removed then row.button.scripts.OnClick();found=true;break end
end
assert(found and #NR.BurstSpells.Get(251)==3)
C_Spell.GetSpellInfo=function(id)
 if id==999991 then return {name='Custom Burst',iconID=1} end
 if id==999992 then return {name={secret=true}} end
end
u.input:SetText('|cff71d5ff|Hspell:999991:0|h[Custom Burst]|h|r');u.addButton.scripts.OnClick()
assert(#NR.BurstSpells.Get(251)==4 and NR.BurstSpells.Get(251)[4]==999991)
u.input:SetText('999991');u.input.scripts.OnEnterPressed()
assert(#NR.BurstSpells.Get(251)==4 and u.message:GetText():find('已经'))
for _,value in ipairs({'bad','999993','999992','|Hitem:999991|h[item]|h'}) do
 u.input:SetText(value);u.addButton.scripts.OnClick();assert(#NR.BurstSpells.Get(251)==4)
end
combat=true;u:Remove(999991);u:Reset();assert(#NR.BurstSpells.Get(251)==4);combat=false
function GetSpecializationInfo() return 252 end
u:Remove(999991)
assert(u.specID==252 and #NR.BurstSpells.Get(251)==4 and not select(2,NR.BurstSpells.Get(252)))
function GetSpecializationInfo() return 251 end
u:Open();u.resetButton.scripts.OnClick();assert(not select(2,NR.BurstSpells.Get(251)))
NR.UI.frame:Hide();assert(not u.frame:IsShown())
""")

    def test_custom_burst_list_drives_next_pull_but_not_saved_boss_plan(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r"""
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
C_SpellBook={IsSpellKnown=function()return true end}
assert(NR.BurstSpells.Save(251,{439843}))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8)
assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==439843)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
assert(NR.BurstSpells.Save(251,{}))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8);assert(#NR.engine.rows==0)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
local own=NR.EventPlans.New(251,9999)
own.rows={{id=1,spellID=51271,anchor='start',occurrence=1,time=5,window=10}}
assert(NR.EventPlans.Save(own))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8)
assert(#NR.engine.rows==1 and NR.engine.rows[1].spellID==51271 and not NR.engine.rows[1].auto)
""")

    def test_frost_default_bursts_use_reviewed_spells_and_learned_talents(self):
        lua,nr=runtime(); lua.globals().NR=nr
        lua.execute(r"""
C_SpellBook={IsSpellKnown=function() return true end}
local p=NR.EventPlans.Default(251,9999)
local expected={[51271]=true,[439843]=true,[1249658]=true}
assert(p and #p.rows==3,'Frost defaults: Pillar, Reapers Mark, Breath')
for _,row in ipairs(p.rows) do
 assert(expected[row.spellID],'no obsolete or utility spell in Frost defaults')
 expected[row.spellID]=nil
end
assert(next(expected)==nil)
C_SpellBook.IsSpellKnown=function(id) return id==51271 or id==47568 end
p=NR.EventPlans.Default(251,9999)
assert(p and #p.rows==1 and p.rows[1].spellID==51271,'unlearned talents omitted; old Rune Weapon never auto-added')
""")

    def test_unconfigured_mplus_boss_uses_builtin_burst_ready_reminders(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r"""
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
readyCalls={};local emit=NR.Display.Emit
NR.Display.Emit=function(self,kind,row,value) if kind=='show' and row and row.postReady then readyCalls[#readyCalls+1]=row.id end return emit(self,kind,row,value) end
assert(NR.db.settings.autoBurst==nil or NR.Settings(NR.db.settings).autoBurst)
local cd={}
C_Spell.GetSpellCooldown=function(id) return {isEnabled=true,isActive=cd[id]=='cooling',isOnGCD=false} end
local d=NR.EventPlans.Default(251,9999); assert(d and #d.rows>0 and d.auto)
local spell=d.rows[1].spellID
for _,row in ipairs(d.rows) do
 local entry=NR.SpellCatalog.Get(row.spellID); local primary=false
 for _,id in ipairs(entry.primarySpecs) do primary=primary or id==251 end
 assert(primary and row.anchor=='start' and row.after=='ready')
end
now=0;driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8)
assert(NR.engine.rows[1] and NR.engine.rows[1].auto and NR.engine.rows[1].shown, 'pull reminder')
now=20;NR.engine:Tick(20);assert(NR.engine.rows[1].done,'pull reminder expires unused')
now=40;driver.scripts.OnEvent(driver,'UNIT_SPELLCAST_SUCCEEDED','player','',spell)
assert(NR.engine.readyWatches[NR.engine.rows[1].id],'late first use still starts ready reminders')
cd[spell]='cooling';driver.scripts.OnEvent(driver,'SPELL_UPDATE_COOLDOWN');now=41;NR.engine:Tick(41)
local before=#readyCalls
cd[spell]='ready';now=100;NR.engine:Tick(100)
assert(NR.engine.rows[1].shown and #readyCalls==before+1,'reminded when ready again')
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
-- Raid difficulty, disabled setting, or a configured plan do not use the fallback.
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',16); assert(#NR.engine.rows==0)
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
NR.db.settings.autoBurst=false
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8); assert(#NR.engine.rows==0)
driver.scripts.OnEvent(driver,'ENCOUNTER_END'); NR.db.settings.autoBurst=true
local own=NR.EventPlans.New(251,9999); own.rows={{id=1,spellID=51271,anchor='start',occurrence=1,time=5,window=10}}
assert(NR.EventPlans.Save(own))
driver.scripts.OnEvent(driver,'ENCOUNTER_START',9999,'',8)
assert(#NR.engine.rows==1 and not NR.engine.rows[1].auto,'configured boss uses the user plan')
driver.scripts.OnEvent(driver,'ENCOUNTER_END')
NR.UI:Refresh(); NR.UI:SetPage('settings'); NR.UI.checks.autoBurst:SetChecked(false); NR.UI:SaveSettings()
assert(NR.db.settings.autoBurst==false)
""")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--report",type=Path)
    args=parser.parse_args()
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(__import__(__name__)))
    if args.report:
        args.report.write_text(json.dumps({
            "STATIC":"PASS" if result.wasSuccessful() else "FAIL",
            "MOCK":"PASS" if result.wasSuccessful() else "FAIL", "LIVE":"NOT_RUN",
            "testsRun":result.testsRun, "failures":len(result.failures), "errors":len(result.errors),
            "skipped":len(result.skipped), "lua":"5.1",
        },ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if not result.wasSuccessful(): raise SystemExit(1)
    print("STATIC Lua 5.1 / MOCK passed; LIVE NOT_RUN. UI layout, audio and protected frame behavior require game tests.")
