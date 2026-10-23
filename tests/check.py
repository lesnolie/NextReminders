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
C_Spell={GetSpellInfo=function(id) return {name="Spell "..id,iconID=id} end}
voiceCalls={}
C_VoiceChat={GetTtsVoices=function() return {{voiceID=1}} end,
 SpeakText=function(_,text) voiceCalls[#voiceCalls+1]=text end}
Enum={EncounterTimelineEventState={Active=0,Paused=1,Finished=2,Canceled=3}}
C_EncounterTimeline={GetEventState=function() return 3 end}
'''


def runtime(all_files=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    nr = lua.table()
    names = ["Core.lua", "SpellCatalog.lua", "Theme.lua", "BossRules.lua", "BossData.lua", "DungeonData.lua", "Import.lua", "EventPlans.lua", "TimelinePlans.lua", "BossEvents.lua", "Ready.lua", "Engine.lua", "Preview.lua"]
    if all_files: names += ["Sounds.lua", "Display.lua", "PreviewUI.lua", "UI.lua", "Main.lua"]
    for name in names:
        chunk = lua.execute("return assert(loadstring(...))",(ADDON/name).read_text(encoding="utf-8"))
        chunk("NextReminders",nr)
    return lua, nr


class PluginTests(unittest.TestCase):

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
assert(editor.parent:GetVerticalScroll()==362)
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
assert(editor:GetText()==text and ui.encounter:GetText()=='' and not next(NR.db.plans))
''')

    def test_shared_burst_catalog_all_specs_and_web_lua_scope_match(self):
        import subprocess
        check=subprocess.run(['python','tools/sync_spell_catalog.py','--check'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(check.returncode,0,check.stderr)
        data=json.loads((ROOT/'web/burst-spells.json').read_text(encoding='utf-8'))
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
            self.assertTrue((ROOT/'web'/r['image']).is_file())
        self.assertIsNone(nr.SpellCatalog.Get(200166),'Havoc effect ID must not replace the cast ID')
        self.assertIsNone(nr.SpellCatalog.Get(1217607),'Devourer effect ID must not replace the cast ID')
        self.assertIsNone(nr.SpellCatalog.Get(442204),'Breath of Eons effect ID must not replace the cast ID')
        lua.execute('local x=NR.SpellCatalog.ForSpec(251);x[1].name="edited";assert(NR.SpellCatalog.Get(x[1].id).name~="edited")')

    def test_all_spec_builtin_selection_round_trips_and_cast_clears_reminder(self):
        import subprocess
        code=r"""
import {SPECS,newDungeon,generateDungeon} from './web/plan.mjs';
import {burstSpellsForSpec} from './web/spells.mjs';
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
assert(s.soundChoice=='meow' and s.soundFile==nil)
local d=NR.Settings({});assert(d.soundChoice=='meow' and d.readySound==nil and d.missSound==nil)
assert(NR.Sounds.Find('kit:READY_CHECK','meow').key=='meow','old client-sound choices fall back to the default clip')
assert(NR.Sounds.Play('kit:READY_CHECK')==nil and NR.Sounds.Play('off')==nil and #files==0 and #kits==0,'unknown or off plays nothing')
-- Only "off" plus the ten bundled clips: no client sounds, no LibSharedMedia, no custom file.
local list=NR.Sounds.List();assert(list[1].key=='off' and #list==11)
for i=2,#list do local e=list[i];assert(e.file and e.voice and e.length>0)
 local f=io.open('NextReminders/Media/'..e.file:match('([%w_]+%.ogg)$'),'rb');assert(f,e.file);f:close() end
-- Reminder: one voice clip for reminders shown together; it replaces the spell-name TTS and the countdown while it plays.
NR.db.settings=NR.Settings({sound=true,tts=true})
now=100;local before=#voiceCalls
-- Shown early: spell names are spoken, then 3, 2, 1, and the clip plays when time is up (once for both rows).
NR.Display:Emit('show',{id=1,spellID=42650,target=105},5);NR.Display:Emit('show',{id=2,spellID=1233448,target=105},5)
assert(#files==0 and #voiceCalls==before+2,'clip waits for the moment')
now=102;NR.Display:Emit('countdown',{id=1},3);now=103;NR.Display:Emit('countdown',{id=1},2);now=104;NR.Display:Emit('countdown',{id=1},1)
assert(voiceCalls[#voiceCalls]=='1' and #files==0)
now=104.5;NR.Display:Emit('update',{id=1},0.5);assert(#files==0)
now=105;NR.Display:Emit('update',{id=1},0);NR.Display:Emit('update',{id=2},0)
assert(#files==1 and files[1]:find('burst_meow.ogg',1,true),'one clip at time-up')
NR.Display:Emit('update',{id=1},-1);assert(#files==1,'played once per reminder')
-- A countdown number while a clip still plays waits for it.
now=105.5;before=#voiceCalls;NR.Display:Emit('countdown',{id=1},3);assert(#voiceCalls==before)
-- Ready again uses the same reminder sound.
NR.Display:Clear();now=110;NR.Display:Emit('show',{id=5,spellID=42650,target=110,postReady=true},0);assert(files[#files]:find('burst_meow.ogg',1,true))
-- An unused reminder that expires plays nothing more.
local e=NR.Engine.New(function(kind,row,value)NR.Display:Emit(kind,row,value)end)
NR.Display:Clear();NR.db.settings=NR.Settings({sound=true});local n=#files
now=0;e:Begin(3101,'mythic',nil,{lead=5,window=10},0,{specID=252},NR.EventPlans.New(252,3101))
now=0;e:Tick(0);now=11;NR.Display.soundUntil=nil;e:Tick(11);assert(#files==n+1,'expiry is silent')
-- A clip the client refuses: TTS still speaks.
NR.Display:Clear();PlaySoundFile=function()return false end
NR.db.settings=NR.Settings({sound=true,tts=true,soundChoice='rita_ready'})
now=300;before=#voiceCalls;NR.Display:Emit('show',{id=4,spellID=42650,target=300},0);assert(#voiceCalls==before+1)
PlaySoundFile=function(path)files[#files+1]=path;return true end
-- The picker opens the addon's own light list: one row per clip, current one marked; a pick selects, previews and closes.
local ui=NR.UI;ui:SetPage('settings');ui:Refresh()
local pick=ui.soundPicks.soundChoice;assert(ui.soundValues.soundChoice=='rita_ready' and pick:GetText():find('丽塔',1,true))
pick.scripts.OnClick(pick);local menu=NR.Theme.menuFrame
assert(menu.shown and menu.height==11*28+12)
local shown=0;for _,row in ipairs(menu.rows)do if row.shown then shown=shown+1 end end;assert(shown==11)
assert(menu.rows[9].mark.shown and not menu.rows[2].mark.shown,'current clip is marked')
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
assert(NR.Display.rows[42].label:GetText()=='亡者大军' and voiceCalls[#voiceCalls]=='亡者大军')
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
assert(scroll:GetVerticalScroll()==360 and editor:GetHeight()>=624,'caret must stay in the visible scroll area')
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

    def test_display_future_countdown_due_now_waiting_and_translucent_background(self):
        lua,nr=runtime(True);lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],'ADDON_LOADED','NextReminders')
NR.db.settings.tts=false;NR.db.settings.countdown=false
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
        code="import {newDungeon,newPlan,generateDungeon} from './web/plan.mjs';const d=newDungeon();d.plans[0]=newPlan();d.plans[3].rows=[{type:'spell',value:42650,anchor:'start',occurrence:1,time:0,window:10,hold:''}];process.stdout.write(generateDungeon(d).text);"
        return subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout

    def test_dungeon_catalog_matches_runtime_all_bosses_and_scopes(self):
        import subprocess
        data=json.loads(subprocess.run(['node','--input-type=module','-e',"import {DUNGEONS} from './web/plan.mjs';console.log(JSON.stringify(DUNGEONS));"],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout)
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
NR.db.plans['3492:heroic']={unchanged=true}
local invalid=NR.Copy(b);invalid.plans[2].encounterID=3457
assert(not NR.EventPlans.SaveDungeon(invalid));assert(NR.EventPlans.Get(252,3101,'mythic').rows[2].time==7)
combat=true;assert(not NR.EventPlans.SaveDungeon(b));combat=false
assert(NR.EventPlans.SaveDungeon(b));assert(not NR.EventPlans.Get(252,3102,'mythic'))
assert(NR.EventPlans.Get(251,3102,'mythic') and NR.EventPlans.Get(252,3102,'heroic') and NR.db.plans['3492:heroic'].unchanged)
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
NR.UI:Play();assert(NR.preview.plan.encounterID==3101 and NR.PreviewUI.boss:IsShown())
NR.PreviewUI.boss.scripts.OnClick();assert(NR.preview.plan.encounterID==3105)
NR.PreviewUI.boss.scripts.OnClick();assert(NR.preview.plan.encounterID==3101)
NR.UI:Save();assert(NR.db.lastPlanKind=='dungeon' and NR.EventPlans.Get(252,3105,'mythic'))
NR.db.plans['3101:mythic']=assert(NR.ParseNote('{time:00:00} - player {spell:51271}',{encounterID=3101}))
NR.db.plans['3102:mythic']=assert(NR.ParseNote('{time:00:00} - player {spell:51271}',{encounterID=3102}))
NR.db.plans['3101:mythic'].enabled=true;NR.db.plans['3102:mythic'].enabled=true
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
SlashCmdList.NEXTREMINDERS('preview');assert(NR.preview.plan.encounterID==3101 and NR.PreviewUI.selectedDungeon)
NR.preview:Stop();NR.PreviewUI.frame:Hide()
NR.UI.note:SetText(note..'broken');NR.UI:Save();assert(NR.db.lastPlanKind=='dungeon')
NR.UI:Parse();assert(not NR.UI.preview)
NR.UI.pausePlan.scripts.OnClick();assert(not NR.EventPlans.Get(252,3105,'mythic'))
""")

    def test_dungeon_all_catalog_bosses_load_without_special_event_definition(self):
        import subprocess
        code="import {DUNGEONS,newDungeon,generateDungeon} from './web/plan.mjs';const notes=DUNGEONS.map(d=>{const p=newDungeon(252,d.id);for(const b of p.plans)b.rows=[{type:'spell',value:1233448,anchor:'start',occurrence:1,time:0,window:10,hold:'',after:'ready'}];return generateDungeon(p).text;});console.log(JSON.stringify(notes));"
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
import {SPECS,newDungeon,generateDungeon,validateDungeon} from './web/plan.mjs';
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

    def test_redesigned_website_preserves_saved_and_legacy_drafts(self):
        import subprocess
        code=r"""
import assert from 'node:assert/strict';
import {newDungeon,generateDungeon} from './web/plan.mjs';
import {loadDraft,saveDraft,draftKey,lastContext,rememberContext} from './web/drafts.mjs';
const data=new Map();const storage={getItem:k=>data.get(k)||null,setItem:(k,v)=>data.set(k,v)};
const old=newDungeon(252,2813);
old.plans[0].rows=[{type:'spell',value:42650,anchor:'vuln',occurrence:1,time:3,window:10,hold:'等易伤',after:'ready'}];
old.plans[3].rows=[{type:'slot',value:13,anchor:'dog',occurrence:1,time:0,window:10,hold:''}];
data.set(draftKey(252,2813),JSON.stringify(old));
const restored=loadDraft(storage,252,2813);assert.deepEqual(restored,old);
assert.equal(generateDungeon(restored).bundle.plans.length,2);
restored.plans[0].rows[0].time=4;assert.equal(JSON.parse(data.get(draftKey(252,2813))).plans[0].rows[0].time,3);
saveDraft(storage,restored);assert.equal(loadDraft(storage,252,2813).plans[0].rows[0].time,4);
assert(loadDraft(storage,251,2813).plans.every(p=>p.rows.length===0));
const bad=structuredClone(old);bad.plans[0].rows[0].time=-1;assert.throws(()=>saveDraft(storage,bad));
assert.equal(loadDraft(storage,252,2813).plans[0].rows[0].time,4,'failed validation preserves saved draft');
data.set(draftKey(251,2813),JSON.stringify(old));assert(loadDraft(storage,251,2813).plans.every(p=>!p.rows.length),'wrong context cannot load');
data.delete(draftKey(252,2813));data.set('nr-plan:252:3101:mythic',JSON.stringify(old.plans[0]));
const migrated=loadDraft(storage,252,2813);assert.deepEqual(migrated.plans[0].rows,old.plans[0].rows);
assert(data.has('nr-plan:252:3101:mythic'),'migration does not erase old data');
assert(migrated.plans.slice(1).every(p=>!p.rows.length));
data.set(draftKey(252,2813),'broken');assert(loadDraft(storage,252,2813).plans.every(p=>!p.rows.length));
const unavailable={getItem(){throw Error('unavailable')},setItem(){throw Error('quota')}};
assert(loadDraft(unavailable,252,2813).plans.every(p=>!p.rows.length));assert.throws(()=>saveDraft(unavailable,old),/quota/);
assert.deepEqual(lastContext(storage),{specID:252,dungeonID:2813});rememberContext(storage,{specID:251,dungeonID:2993});
assert.deepEqual(lastContext(storage),{specID:251,dungeonID:2993});
data.set('nr-last-context',JSON.stringify({specID:0,dungeonID:0}));assert.deepEqual(lastContext(storage),{specID:252,dungeonID:2813});
console.log('saved drafts, migration, context isolation and storage failures PASS');
"""
        r=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(r.returncode,0,r.stderr)

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
local before=#voiceCalls
NR.engine:Tick(32.2);assert(#voiceCalls==before,'ready immediately after cast is not a completed cooldown edge')
cd[42650]='cooling';now=33;driver.scripts.OnEvent(driver,'SPELL_UPDATE_COOLDOWN',{secret=true});NR.engine:Tick(33);assert(#voiceCalls==before)
cd[42650]='ready';NR.engine:Tick(80)
assert(#voiceCalls==before+1 and voiceCalls[#voiceCalls]=='Spell 42650好了')
NR.engine:Tick(81);NR.engine:Tick(92);assert(#voiceCalls==before+1,'one voice per edge')
cd[42650]='cooling';NR.engine:CooldownUpdate(93);NR.engine:Tick(93);cd[42650]='ready';NR.engine:Tick(140)
assert(#voiceCalls==before+2,'voice repeats after the next real cooldown')
driver.scripts.OnEvent(driver,'ENCOUNTER_END');cd[42650]='cooling';NR.engine:Tick(150);cd[42650]='ready';NR.engine:Tick(200)
assert(#voiceCalls==before+2 and not next(NR.engine.readyWatches))
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
cd[42650]='cooling';NR.engine:CooldownUpdate(401);NR.engine:Tick(401);before=#voiceCalls;cd[42650]='ready';NR.engine:Tick(500)
assert(#voiceCalls==before+1,'late first use still voices the next ready')
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
        code="import {newPlan,exportPlan} from './web/plan.mjs';process.stdout.write(exportPlan(newPlan()));"
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
    def test_local_web_server_module_mime_and_bounded_cli_adapter(self):
        import importlib.util
        from unittest.mock import patch
        from types import SimpleNamespace
        spec=importlib.util.spec_from_file_location('nr_web',ROOT/'tools/web_server.py')
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        self.assertEqual(mod.Handler.extensions_map['.mjs'],'text/javascript')
        self.assertEqual(mod.Handler.extensions_map['.webp'],'image/webp')
        self.assertEqual(mod.Handler.extensions_map['.png'],'image/png')
        request=dict(mode='top',boss=3492,className='Mage',specName='Fire',rank=1,difficulty=4,rankingID=1234)
        with patch.object(mod.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='note',stderr='')) as run:
            self.assertEqual(mod.read_wcl(request),{'note':'note'})
            args=run.call_args.args[0]
            self.assertIn('--ranking-id',args);self.assertIn('1234',args);self.assertIn('3492',args)
            self.assertFalse(run.call_args.kwargs.get('shell',False))
        for change in (dict(boss=0),dict(mode='shell'),dict(className='Mage;cmd'),dict(spells='1;cmd'),dict(rank=21)):
            with self.assertRaises(ValueError):mod.read_wcl({**request,**change})

    def test_web_exports_round_trip_real_lua_and_refuse_lossy_conversion(self):
        import subprocess
        code=r'''
import {SPECS,newPlan,exportPlan} from './web/plan.mjs';
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
ui.lead:SetText("7"); ui.window:SetText("8"); ui.volume:SetText("65"); ui.glow:SetText("player")
for _,key in ipairs({"hideOnUse","tts","countdown","sound"}) do ui.checks[key]:SetChecked(true) end
ui.saveSettings.scripts.OnClick()
assert(NR.db.settings.lead==7 and NR.db.settings.volume==65 and NR.db.settings.glow=="player")
combat=true; ui.lead:SetText("9"); ui.saveSettings.scripts.OnClick(); assert(NR.db.settings.lead==7)
combat=false; ui.importTab.scripts.OnClick()
assert(ui.note:GetText()==text and ui.preview==plan and ui.importPage:IsShown() and not ui.settingsPage:IsShown())
ui.saveButton.scripts.OnClick(); assert(NR.db.plans["3492:mythic"].enabled)
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
assert(p:Seek(129,1503)); assert(not p.engine.rows[1].shown and not p.engine.rows[1].done and #p.actions==0)
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
local saved=NR.db.plans["3492:heroic"]
NR.UI.playPreview.scripts.OnClick(); assert(NR.PreviewUI.frame:IsShown() and NR.preview.running)
assert(not NR.engine.active and #NR.engine.trace==0)
NR.PreviewUI.seek:SetText("130.5"); NR.PreviewUI.jump.scripts.OnClick()
assert(NR.Display.rows[1].label:GetText():find("预览",1,true))
assert(NR.Display.previewMode and NR.Display.container.point[1]=="TOP")
NR.PreviewUI.rows[1].use.scripts.OnClick(); assert(NR.preview.engine.rows[1].done)
assert(NR.db.plans["3492:heroic"]==saved and saved.rows[1].time==135.5 and not saved.rows[1].done)
now=1000; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
assert(not NR.preview.running and not NR.PreviewUI.frame:IsShown() and NR.engine.active)
assert(not NR.Display.previewMode and NR.Display.container.point[1]=="CENTER")
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
NR.PreviewUI.phase.scripts.OnClick(); assert(NR.preview.engine.rows[1].target==3)
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
NR.UI:Save(); assert(not NR.db.plans["9999:heroic"])
''')

    def test_preview_finishes_and_restarts_without_saved_changes(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\nph:1;time:5;spellid:51271;")
assert(NR.PreviewUI:Open(plan))
now=16; created[1].scripts.OnUpdate(created[1],0.1)
assert(not NR.preview.running and NR.preview.status=="播放结束")
assert(not NR.Display.rows[1]:IsShown())
NR.PreviewUI.play.scripts.OnClick(); assert(NR.preview.running and NR.preview.position==0)
assert(NR.Display.rows[1]:IsShown())
NR.PreviewUI.stop.scripts.OnClick(); assert(not NR.preview.running and not NR.Display.rows[1]:IsShown())
assert(next(NR.db.plans)==nil)
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
local original=NR.db.plans["3492:mythic"]
NR.UI.difficultyButton.scripts.OnClick(NR.UI.difficultyButton)
assert(NR.UI.difficulty=="heroic")
NR.UI:Parse(); NR.UI:Save()
assert(NR.db.plans["3492:mythic"]==original)
assert(NR.db.plans["3492:heroic"].sourceDifficulty=="mythic")
assert(NR.UI.summary:GetText():find("来源",1,true))
now=100; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
assert(#NR.engine.rows==1 and NR.engine.rows[1].target==245.5)
now=240.5; driver.scripts.OnUpdate(driver,0.1); assert(NR.engine.rows[1].shown)
driver.scripts.OnEvent(driver,"ENCOUNTER_END")
driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",14)
assert(#NR.engine.rows==0)
NR.UI:Parse(); NR.UI.difficulty="normal"; NR.UI:Save()
assert(not NR.db.plans["3492:normal"])
''')

    def test_demo_command_uses_real_scheduler_and_cleans_up(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local driver=created[1]
driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
now=100; SlashCmdList.NEXTREMINDERS("test")
assert(NR.preview.running and #NR.preview.engine.rows==1 and NR.preview.engine.rows[1].shown)
assert(not NR.engine.active and #NR.engine.trace==0, "demo must not alter the live engine")
assert(NR.Display.rows[1]:IsShown() and #voiceCalls>0)
assert(next(NR.db.plans)==nil, "demo must not create a saved boss plan")
now=102.1; driver.scripts.OnUpdate(driver,0.1); assert(voiceCalls[#voiceCalls]=="3")
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",{secret=true})
assert(not NR.preview.engine.rows[1].done)
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",51271)
assert(NR.preview.engine.rows[1].done and not NR.Display.rows[1]:IsShown())
SlashCmdList.NEXTREMINDERS("stop"); assert(not NR.preview.running and not NR.engine.active)
SlashCmdList.NEXTREMINDERS("test"); now=119; driver.scripts.OnUpdate(driver,0.1)
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
NR.UI:Save(); assert(NR.db.plans["3101:mythic"].phaseBindings[3]==3)
local count=#created; NR.UI:Parse()
assert(#created==count and NR.UI.binders[1]==a and NR.UI.binders[2]==b)
assert(not NR.UI.preview.phaseBindings[2] and not NR.UI.preview.phaseBindings[3])
NR.UI.personal:SetChecked(false); NR.UI:Refresh(); assert(not NR.UI.personal:GetChecked())
''')

    def test_native_glow_aliases_visibility_and_reference_counts(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
PlayerFrame=object(); PlayerFrame:Show()
CompactRaidGroup1Member1=object(); CompactRaidGroup1Member1.unit="raid1"; CompactRaidGroup1Member1:Show()
NR.db.settings.glow="Leslie-Realm"
NR.Display:CacheFrames(); assert(#NR.Display.frameCache["leslie-realm"]==2)
NR.Display:SetGlow(1,true); NR.Display:SetGlow(2,true)
local playerGlow=NR.Display.glows[PlayerFrame].overlay
assert(playerGlow.alpha==1)
NR.Display:SetGlow(1,false); assert(playerGlow.alpha==1)
PlayerFrame:Hide(); NR.Display:RefreshGlows(); assert(playerGlow.alpha==0)
PlayerFrame:Show(); NR.Display:RefreshGlows(); assert(playerGlow.alpha==1)
NR.db.settings.glow="Other"; NR.Display:SetGlow(2,false); assert(playerGlow.alpha==0)
UnitName=function() return "北霜","Realm" end
NR.db.settings.glow="北霜-Realm，Other"; NR.Display:CacheFrames()
NR.Display:SetGlow(3,true); assert(playerGlow.alpha==1, "UTF-8 names must remain intact")
NR.Display:SetGlow(3,false); assert(playerGlow.alpha==0)
combat=true; local count=#created; NR.Display:CacheFrames(); assert(#created==count)
NR.Display:Clear(); assert(NR.Display.glows[CompactRaidGroup1Member1].overlay.alpha==0)
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
e:Begin(3492,"heroic",p,{lead=5,window=10},0,{})
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
assert(NR.db.plans["3492:heroic"].enabled)
combat=true; NR.UI.note:SetText("bad"); NR.UI:Parse()
assert(NR.db.plans["3492:heroic"].rows[1].time==10)
now=100; driver.scripts.OnEvent(driver,"ENCOUNTER_START",3492,"Ulatek",15)
now=105; driver.scripts.OnUpdate(driver,0.1); assert(NR.engine.rows[1].shown)
driver.scripts.OnEvent(driver,"UNIT_SPELLCAST_SUCCEEDED","player","cast",51271)
assert(NR.engine.rows[1].done)
driver.scripts.OnEvent(driver,"ENCOUNTER_END"); assert(not NR.engine.active)
combat=false
NR.UI.note:SetText("{time:00:10} - X {spell:51271}"); NR.UI.encounter:SetText("3492"); NR.UI:Parse()
NR.UI.encounter:SetText("3105"); NR.UI:Save(); assert(not NR.db.plans["3105:mythic"])
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
local tl=NR.PreviewUI.timeline;assert(NR.PreviewUI.span==60,tostring(NR.PreviewUI.span))
tl.GetLeft=function()return 100 end;tl.GetEffectiveScale=function()return 1 end
GetCursorPosition=function()return 100+24+944/2,0 end
tl.scripts.OnMouseDown(tl,"LeftButton")
assert(NR.preview.running and math.abs(NR.preview.position-30)<0.1,tostring(NR.preview.running)..' '..tostring(NR.preview.position)..' '..tostring(NR.PreviewUI.message:GetText()))
local row=NR.Display:Row(99);assert(row.backdropColor[4]<=0.2 and not rawget(row,"nrFill"),'reminder bar keeps the old see-through look')
''')

    def test_cleanup_on_close_and_fight_end_waits_for_combat_and_stops_voice(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r'''
local collected,stopped,mem=0,{},300
collectgarbage=function(what) if what=="collect" then collected=collected+1;mem=120 end return 0 end
UpdateAddOnMemoryUsage=function() end
GetAddOnMemoryUsage=function(name) assert(name=="NextReminders");return mem end
StopSound=function(h) stopped[#stopped+1]=h end
PlaySoundFile=function() return true,77 end
C_VoiceChat.StopSpeakingText=function() stopped[#stopped+1]="tts" end
local driver=created[1];driver.scripts.OnEvent(driver,"ADDON_LOADED","NextReminders")
NR.db.settings=NR.Settings({sound=true})
now=10;NR.Display:Emit("show",{id=1,spellID=42650,target=10},0)
-- Closing the window stops the clip that is still playing and collects garbage.
NR.UI.frame:Show();NR.UI.frame:Hide()
assert(collected==1 and stopped[1]==77 and stopped[2]=="tts" and NR.lastCleanup=="close")
assert(not NR.Display.rows[1]:IsShown())
-- In combat it waits, then runs once combat ends.
combat=true;local ok,err=NR.Cleanup("manual");assert(not ok and err:find("脱战") and collected==1)
combat=false;driver.scripts.OnEvent(driver,"PLAYER_REGEN_ENABLED");assert(collected==2 and not NR.cleanupPending)
-- Fight end: cleaned when it is already out of combat; a rehearsal in progress is left alone.
driver.scripts.OnEvent(driver,"ENCOUNTER_END");assert(collected==3 and NR.lastCleanup=="encounter")
NR.preview.running=true;assert(not NR.Cleanup("manual") and collected==3);NR.preview.running=false
-- Settings card button shows before and after.
mem=300;NR.UI.frame:Show();NR.UI:SetPage("settings");NR.UI.cleanButton.scripts.OnClick()
assert(NR.UI.memoryLabel:GetText()=="300 KB → 120 KB",NR.UI.memoryLabel:GetText())
SlashCmdList.NEXTREMINDERS("gc");assert(messages[#messages]:find("KB"))
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
NR.UI:Save(); assert(not NR.db.plans["3470:mythic"], "unbound 1.75 must block save")
local box=NR.UI.fallbacks[2]; box:SetText("1:40"); box.scripts.OnTextChanged(box)
assert(NR.UI.preview.phaseBindings[1.75]=="time" and NR.UI.preview.phaseFallback[1.75]==100)
NR.UI:Save(); assert(NR.db.plans["3470:mythic"].phaseFallback[1.75]==100)
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


    def test_unconfigured_mplus_boss_uses_builtin_burst_ready_reminders(self):
        lua,nr=runtime(True); lua.globals().NR=nr
        lua.execute(r"""
local driver=created[1];driver.scripts.OnEvent(driver,'ADDON_LOADED','NextReminders')
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
local before=#voiceCalls
cd[spell]='ready';now=100;NR.engine:Tick(100)
assert(NR.engine.rows[1].shown and #voiceCalls==before+1,'reminded when ready again')
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
