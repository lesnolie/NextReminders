// Data-only format shared by the website and tested against the real Lua importer.
export const SPECS = [
  ['DeathKnight','死亡骑士',[[250,'Blood','鲜血'],[251,'Frost','冰霜'],[252,'Unholy','邪恶']]],
  ['DemonHunter','恶魔猎手',[[577,'Havoc','浩劫'],[581,'Vengeance','复仇'],[1480,'Devourer','Devourer']]],
  ['Druid','德鲁伊',[[102,'Balance','平衡'],[103,'Feral','野性'],[104,'Guardian','守护'],[105,'Restoration','恢复']]],
  ['Evoker','唤魔师',[[1467,'Devastation','湮灭'],[1468,'Preservation','恩护'],[1473,'Augmentation','增辉']]],
  ['Hunter','猎人',[[253,'BeastMastery','野兽控制'],[254,'Marksmanship','射击'],[255,'Survival','生存']]],
  ['Mage','法师',[[62,'Arcane','奥术'],[63,'Fire','火焰'],[64,'Frost','冰霜']]],
  ['Monk','武僧',[[268,'Brewmaster','酒仙'],[270,'Mistweaver','织雾'],[269,'Windwalker','踏风']]],
  ['Paladin','圣骑士',[[65,'Holy','神圣'],[66,'Protection','防护'],[70,'Retribution','惩戒']]],
  ['Priest','牧师',[[256,'Discipline','戒律'],[257,'Holy','神圣'],[258,'Shadow','暗影']]],
  ['Rogue','潜行者',[[259,'Assassination','奇袭'],[260,'Outlaw','狂徒'],[261,'Subtlety','敏锐']]],
  ['Shaman','萨满祭司',[[262,'Elemental','元素'],[263,'Enhancement','增强'],[264,'Restoration','恢复']]],
  ['Warlock','术士',[[265,'Affliction','痛苦'],[266,'Demonology','恶魔学识'],[267,'Destruction','毁灭']]],
  ['Warrior','战士',[[71,'Arms','武器'],[72,'Fury','狂怒'],[73,'Protection','防护']]],
].flatMap(([className,classLabel,specs])=>specs.map(([id,specName,label],i)=>({id,className,classLabel,specName,label,index:i+1})));

import {DUNGEONS} from './dungeons.mjs';
export {DUNGEONS};
export const BOSSES=DUNGEONS.flatMap(d=>d.bosses.map(([id,label],i)=>({id,name:`${d.name} 老${['一','二','三','四'][i]} · ${label}`,dungeonID:d.id})));
export function eventOptions(boss,difficulty) {
  const known={3101:[['vuln','易伤开始',1.7]],3105:[['dog','第一次放狗',10]],3457:[['p2','分体（待核对）',0]],2125:[['snakes','召蛇（证据弱）',13]]};
  return [['start','开战',0],...(difficulty==='mythic'?(known[boss]||[]):[])];
}
import {spellNames} from './spells.mjs';
export {spellNames};
export function newPlan(specID=252,encounterID=3101,difficulty='mythic') {
  const p={specID,encounterID,difficulty,name:BOSSES.find(b=>b.id===encounterID)?.name||`首领 ${encounterID}`,rows:[],source:'手动方案'};
  if(specID===252&&encounterID===3101&&difficulty==='mythic') {
    p.source='你的邪DK示例（自有事件识别待游戏核对）';
    p.rows=[
      {type:'spell',value:1233448,anchor:'start',occurrence:1,time:0,window:10,hold:''},
      {type:'spell',value:42650,anchor:'vuln',occurrence:1,time:0,window:10,hold:'亡者大军：留着，等第一次易伤',after:'ready'},
      {type:'spell',value:1233448,anchor:'vuln',occurrence:1,time:0,window:10,hold:'',after:'ready'},
      {type:'text',value:'药水与主动饰品',anchor:'vuln',occurrence:1,time:0,window:10,hold:''},
    ];
  }
  return p;
}
const integer=(v,min,max)=>Number.isInteger(v)&&v>=min&&v<=max;
const byteLength=s=>new TextEncoder().encode(s).length;
export function validate(p) {
  if(!integer(p.encounterID,1,1000000)||!SPECS.some(s=>s.id===p.specID)||!['normal','heroic','mythic'].includes(p.difficulty))throw Error('请选择正确的首领、专精和难度');
  if(!Array.isArray(p.rows)||!p.rows.length||p.rows.length>100)throw Error('需要1～100条规则');
  const readySpells=new Set();
  for(const r of p.rows) {
    if(!eventOptions(p.encounterID,p.difficulty).some(o=>o[0]===r.anchor))throw Error('此首领/难度尚未支持所选事件');
    if(!Number.isFinite(r.time)||r.time<0||r.time>3600||Math.abs(r.time*10-Math.round(r.time*10))>1e-6||!Number.isFinite(r.window)||r.window<.1||r.window>60)throw Error('时间须为0～3600秒，最多一位小数；保留时间为0.1～60秒');
    if(r.occurrence!=='every'&&!integer(r.occurrence,1,20)||r.anchor==='start'&&r.occurrence!==1)throw Error('开战只发生一次；机制次数须为1～20或每次');
    if(r.type==='text') {if(typeof r.value!=='string'||!r.value.trim()||byteLength(r.value)>120)throw Error('请输入不超过120字节的文字');}
    else if(r.type==='slot') {if(![13,14].includes(r.value))throw Error('饰品槽为13或14');}
    else if(!['spell','item'].includes(r.type)||!integer(r.value,1,10000000))throw Error('技能或物品编号无效');
    if(typeof r.hold!=='string'||byteLength(r.hold)>200)throw Error('等待文字超过200字节');
    if(r.after!==undefined){
      if(r.after!=='ready'||r.type!=='spell'||r.occurrence!==1||readySpells.has(r.value))throw Error('后续就绪仅支持第一次的技能行，同一技能只能设置一处');
      readySpells.add(r.value);
    }
  }
  return true;
}
export function exportPlan(p,format='nr') {
  validate(p);
  if(format==='nr') {
    const lines=[`NRPlan:2;EncounterID:${p.encounterID};Difficulty:${p.difficulty};SpecID:${p.specID};Name:${encodeURIComponent(p.name)};`];
    for(const r of p.rows) {
      const action=r.type==='text'?`text:${encodeURIComponent(r.value)}`:`${({spell:'spellid',item:'itemid',slot:'slot'})[r.type]}:${r.value}`;
      lines.push(`anchor:${r.anchor};occurrence:${r.occurrence};time:${r.time.toFixed(1)};window:${r.window};${action};${r.hold?`hold:${encodeURIComponent(r.hold)};`:''}${r.after?'after:ready;':''}`);
    }
    return lines.join('\n')+'\n';
  }
  if(!['mrt','nsrt'].includes(format))throw Error('未知导出格式');
  if(p.rows.some(r=>r.anchor!=='start'||r.occurrence!==1||r.type!=='spell'||r.hold||r.after))throw Error('此方案含事件、后续就绪或物品/文字规则，请复制本插件格式。通用导出需要固定时间的技能安排，不能省略这些规则。');
  const s=SPECS.find(s=>s.id===p.specID);
  const lines=format==='nsrt'?[`EncounterID:${p.encounterID};Difficulty:${p.difficulty[0].toUpperCase()+p.difficulty.slice(1)};Name:${p.name.replace(/[;\r\n]/g,' ')};`]:[];
  for(const r of p.rows) {
    if(format==='nsrt')lines.push(`ph:1;time:${r.time.toFixed(1)};tag:${p.specID};spellid:${r.value};`);
    else {const min=Math.floor(r.time/60),sec=(r.time%60).toFixed(1).padStart(4,'0');lines.push(`{time:${String(min).padStart(2,'0')}:${sec}} - spec:${s.className.toUpperCase()}:${s.index} {spell:${r.value}}`);}
  }
  return lines.join('\n')+'\n';
}
export function parseWclNote(note,specID) {
  const h=note.match(/^EncounterID:(\d+);Difficulty:(\w+);Name:([^;]*);/m);
  if(!h)throw Error('不是可识别的WCL/NSRT静态导出');
  const p={specID,encounterID:Number(h[1]),difficulty:h[2].toLowerCase(),name:h[3],source:note.match(/^# (.*)/m)?.[1]||'导入记录',rows:[]};
  for(const line of note.split('\n')) {
    if(!line.startsWith('ph:'))continue;
    const m=line.match(/^ph:1;time:([\d.]+);tag:[^;]*;spellid:(\d+);$/);
    if(!m)throw Error('这里只读取固定时间个人施法，不推断来源阶段');
    p.rows.push({type:'spell',value:Number(m[2]),anchor:'start',occurrence:1,time:Number(m[1]),window:10,hold:''});
  }
  validate(p);return p;
}

export function newDungeon(specID=252,dungeonID=2813) {
  const d=DUNGEONS.find(d=>d.id===dungeonID);
  if(!d||!SPECS.some(s=>s.id===specID))throw Error('请选择正确的专精和副本');
  return {kind:'dungeon',specID,dungeonID,difficulty:'mythic',name:d.name,
    plans:d.bosses.map(([id])=>({...newPlan(specID,id,'mythic'),rows:[],source:'手动方案'}))};
}
export function validateDungeon(draft,allowEmpty=false) {
  const d=DUNGEONS.find(d=>d.id===draft?.dungeonID);
  if(!d||draft.kind!=='dungeon'||draft.difficulty!=='mythic'||!SPECS.some(s=>s.id===draft.specID)
    ||!Array.isArray(draft.plans)||draft.plans.length>d.bosses.length)throw Error('副本方案结构无效');
  const seen=new Set();let count=0;
  for(const p of draft.plans){
    if(!d.bosses.some(([id])=>id===p.encounterID)||seen.has(p.encounterID)||p.specID!==draft.specID||p.difficulty!=='mythic'||!Array.isArray(p.rows))throw Error('副本内首领、专精或难度不一致');
    seen.add(p.encounterID);
    if(p.rows.length){try{validate(p);}catch(e){throw Error(`${p.name}：${e.message}`);}count++;}
  }
  if(!count&&!allowEmpty)throw Error('请先给至少一只首领添加提醒，再生成方案');
  return true;
}
export function actionName(r){return r.type==='text'?r.value:r.type==='slot'?`饰品${r.value===13?'上':'下'}槽`:r.type==='item'?`物品 ${r.value}`:spellNames[r.value]||`技能 ${r.value}`;}
export function describeRow(p,r){
  const event=eventOptions(p.encounterID,p.difficulty).find(o=>o[0]===r.anchor)?.[1]||r.anchor;
  const count=r.anchor==='start'?'':r.occurrence==='every'?'每次':`第${r.occurrence}次`;
  return `${count}${event}${r.time?`后 ${r.time} 秒`:''} → ${actionName(r)}${r.after?'；首次使用后，每次冷却就绪再次显示并播报':''}`;
}
export function generateDungeon(draft){
  validateDungeon(draft);
  const bundle=structuredClone(draft);bundle.plans=bundle.plans.filter(p=>p.rows.length);
  const lines=[`NRDungeon:1;DungeonID:${bundle.dungeonID};Difficulty:mythic;SpecID:${bundle.specID};Name:${encodeURIComponent(bundle.name)};`];
  for(const p of bundle.plans)lines.push(exportPlan(p).trimEnd());
  const text=lines.join('\n')+'\n';
  if(byteLength(text)>200000)throw Error('整份方案超过200KB，请减少提醒');
  return {bundle,text,summary:bundle.plans.map(p=>({name:p.name,encounterID:p.encounterID,rows:p.rows.map(r=>describeRow(p,r))}))};
}
