import {BOSS_RULES} from './boss-rules.mjs';

const number = (value, min=0, max=3600) => Number.isFinite(value) && value>=min && value<=max;
const round = value => Math.round(value*10)/10;
export function rules(draft) {
  if(draft.encounterID!==3492)throw Error('首个闭环只开放乌拉特克 3492；其他首领待验证');
  const result=BOSS_RULES.encounters[draft.encounterID]?.difficulties[draft.difficulty];
  if(!result) throw Error('此首领难度没有规则');
  return result;
}
export function parseNSRT(text, specID=252) {
  const draft={encounterID:3492,difficulty:'mythic',specID,name:'团本时间轴',rows:[],starts:{'1':0},calibrations:{},original:text};
  for(const raw of text.split(/\r?\n/)) {
    const line=raw.trim(); if(!line || line.startsWith('#'))continue;
    const fields={};
    for(const part of line.split(';').filter(Boolean)) {
      const colon=part.indexOf(':'); if(colon<1)throw Error('无法识别的来源字段');
      const key=part.slice(0,colon).toLowerCase();
      if(key in fields)throw Error('重复来源字段'); fields[key]=part.slice(colon+1);
    }
    if(fields.encounterid) {
      draft.encounterID=Number(fields.encounterid);draft.difficulty=fields.difficulty?.toLowerCase();draft.name=fields.name||draft.name;continue;
    }
    const phase=Number(fields.ph), time=Number(fields.time), spellID=Number(fields.spellid);
    if(!fields.ph||!fields.time||!number(phase,1,100)||!number(time)||!Number.isInteger(spellID)||spellID<1)throw Error('技能行需要有效的 ph（阶段）、time（秒数）和 spellid（技能编号）；请复制 Lorrgs 的 NSRT 文本');
    draft.rows.push({id:draft.rows.length+1,source:{phase,time,spellID,tag:fields.tag,raw},spellID,window:10});
  }
  if(!draft.rows.length||draft.rows.length>100)throw Error('需要 1～100 条技能');
  rules(draft);return rebind(draft);
}
export function regions(draft) {
  const data=rules(draft), result=[];
  for(const stage of data.stages) {
    const phase=String(stage.signal?.value??stage.id.replace(/^p/,''));
    const at=draft.starts[phase]??stage.start;
    if(number(at))result.push({anchor:`stage:${stage.id}`,occurrence:1,at,end:3600,label:stage.label,kind:'stage'});
  }
  result.sort((a,b)=>a.at-b.at);
  for(let i=0;i<result.length-1;i++)result[i].end=result[i+1].at;
  for(const mechanic of data.mechanics)for(const occurrence of mechanic.occurrences) {
    const key=`${mechanic.id}:${occurrence.index}`;
    const at=draft.calibrations[key]?.at??occurrence.at;
    result.push({anchor:`mechanic:${mechanic.id}`,occurrence:occurrence.index,at,
      start:at-(mechanic.preWindow||0),end:at+(mechanic.vulnerableDuration||mechanic.castDuration||0),
      label:mechanic.label,kind:'mechanic',evidence:draft.calibrations[key]?.source||mechanic.evidence});
  }
  return result;
}
export function bindAt(draft,row,at) {
  if(!number(at))throw Error('开战后时间必须为 0～3600 秒');
  const all=regions(draft);
  const region=all.filter(r=>r.kind==='mechanic'&&at>=r.start&&at<r.end).sort((a,b)=>b.at-a.at)[0]
    ||all.filter(r=>r.kind==='stage'&&at>=r.at&&at<r.end).sort((a,b)=>b.at-a.at)[0];
  return {...row,absolute:round(at),anchor:region?.anchor||'start',occurrence:region?.occurrence||1,
    offset:round(at-(region?.at||0)),timing:region?'fixed':'auto',fallback:region?round(at):undefined,
    evidence:region?.evidence||'manual_estimate',error:null};
}
export function rebind(draft) {
  return {...draft,rows:draft.rows.map(row=>{
    if(row.manual)return row;
    const start=draft.starts[String(row.source.phase)];
    if(!number(start))return {...row,absolute:null,error:`来源 P${row.source.phase} 需填写起点`};
    return bindAt(draft,row,start+row.source.time);
  })};
}
export function move(draft,id,at) {
  return {...draft,rows:draft.rows.map(row=>row.id===id?{...bindAt(draft,row,at),manual:true}:row)};
}
export function calibrate(draft,input) {
  if(input.encounterID!==draft.encounterID||input.difficulty!==draft.difficulty||!input.source?.trim())throw Error('校准必须标明相同首领、难度和记录来源');
  const next=structuredClone(draft);
  for(const [phase,at] of Object.entries(input.starts||{})) {
    if(!number(at))throw Error('校准起点无效');next.starts[phase]=at;
  }
  for(const [key,at] of Object.entries(input.mechanics||{})) {
    if(!regions(draft).some(r=>r.kind==='mechanic'&&`${r.anchor.slice(9)}:${r.occurrence}`===key)||!number(at))throw Error('校准机制或时间无效');
    next.calibrations[key]={at,source:input.source};
  }
  next.calibrationSource=input.source;return rebind(next);
}
export function exportTimeline(draft) {
  if(!Number.isInteger(draft.specID)||draft.specID<1||draft.specID>10000)throw Error('专精编号无效');
  if(!draft.rows.length)throw Error('请先导入');
  const data=rules(draft);
  const lines=[`NRPlan:3;EncounterID:${draft.encounterID};Difficulty:${draft.difficulty};SpecID:${draft.specID};Name:${encodeURIComponent(draft.name)};RuleVersion:${BOSS_RULES.dataVersion};`];
  for(const r of draft.rows) {
    if(r.error)throw Error(r.error);
    if(!number(r.offset,-3600)||!number(r.window,.1,60)||!Number.isInteger(r.occurrence)||r.occurrence<1||r.occurrence>20)throw Error('偏移、窗口或次数无效');
    const [kind,...parts]=r.anchor.split(':'),id=parts.join(':');
    const rule=kind==='stage'?data.stages.find(s=>s.id===id):kind==='mechanic'?data.mechanics.find(m=>m.id===id):null;
    if(r.anchor!=='start'&&!rule)throw Error('未知锚点');
    if(r.anchor==='start'&&(r.offset<0||r.occurrence!==1||r.timing!=='auto'))throw Error('开战锚点必须使用非负偏移');
    if(r.timing==='fixed'&&!number(r.fallback))throw Error('请填写固定兜底的开战后秒数');
    if(r.timing==='signal'&&(!rule?.signal?.enabled||r.offset<0))throw Error('无实时信号或负偏移不可达');
    if(!['auto','fixed','signal'].includes(r.timing))throw Error('预测源尚未接入，请使用明确固定兜底');
    if(r.anchor!=='start'&&r.timing==='auto')throw Error('请选择明确固定兜底或实时信号');
    const source=r.source;
    lines.push(`anchor:${r.anchor};occurrence:${r.occurrence};offset:${round(r.offset)};window:${r.window};timing:${r.timing};${r.fallback!==undefined?`fallback:${r.fallback};`:''}spellid:${r.spellID};sourceformat:NSRT;sourcephase:${source.phase};sourcetime:${source.time};sourcespellid:${source.spellID};${source.tag!==undefined?`sourcetag:${encodeURIComponent(source.tag)};`:''}sourceraw:${encodeURIComponent(source.raw)};`);
  }
  return lines.join('\n')+'\n';
}
export class History {
  constructor(value){this.value=structuredClone(value);this.past=[];this.future=[];}
  set(value){this.past.push(this.value);this.value=structuredClone(value);this.future=[];}
  undo(){if(this.past.length){this.future.push(this.value);this.value=this.past.pop();}}
  redo(){if(this.future.length){this.past.push(this.value);this.value=this.future.pop();}}
}
