import {parseNSRT,regions,rebind,move,calibrate,exportTimeline,History} from './timeline.mjs';
import {SPECS,spellNames} from './plan.mjs';
const $=id=>document.getElementById(id), history=new History(null);
const el=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e;};
function message(id,text,error=false){$(id).textContent=text;$(id).classList.toggle('error',error);}
function run(fn){try{fn();message('status','安排已更新，请重新生成字符串。');}catch(e){message('status',e.message,true);}}
function invalidate(){$('output').value='';$('copy').disabled=true;}
function commit(draft){history.set(draft);render();invalidate();}
function input(value,change){const e=el('input');e.type='number';e.step='.1';e.value=value??'';e.onchange=()=>run(()=>change(e.value===''?undefined:Number(e.value)));return e;}
function render(){
  $('undo').disabled=!history.past.length;$('redo').disabled=!history.future.length;
  for(const id of ['starts','rows','timeline','arrangements'])$(id).replaceChildren();
  const d=history.value;
  $('empty').hidden=!!d;$('editorContent').hidden=!d;$('draft').disabled=!d;$('export').disabled=!d;
  $('totalRows').textContent=d?.rows.length||0;$('rowCount').textContent=d?`${d.rows.length} 条`:'';
  const pending=d?.rows.filter(r=>r.error).length||0;$('pendingRows').textContent=pending;
  $('export').disabled=!d||pending>0;
  $('exportHint').textContent=!d?'先导入你的个人安排。':pending?`有 ${pending} 条缺少阶段起点，请在左侧补时间。`:'时间已齐全，可直接生成；原始导入记录会保留。';
  $('phaseStatus').textContent=pending?` · ${pending} 条待补时间`:'';
  if(!d)return;
  $('spec').value=d.specID;
  $('encounterTitle').textContent=`乌拉特克 · ${{heroic:'英雄',mythic:'史诗',normal:'普通'}[d.difficulty]}`;
  $('encounterSubtitle').textContent=`${d.rows.length} 条提醒 · ${SPECS.find(s=>s.id===d.specID)?.label||d.specID} · 来源 ${d.name}`;
  if(pending)$('phaseSettings').open=true;
  const phases=new Set(['1','2','2.5','3',...d.rows.map(r=>String(r.source.phase))]);
  for(const phase of phases){const label=el('label',`P${phase} 起点`);label.append(input(d.starts[phase],at=>{const n=structuredClone(d);if(at===undefined)delete n.starts[phase];else n.starts[phase]=at;commit(rebind(n));}));$('starts').append(label);}
  const rs=regions(d), span=Math.max(180,...rs.map(r=>r.kind==='mechanic'?r.end:0),...d.rows.map(r=>r.absolute||0))+30;
  const ruler=el('div');ruler.className='ruler';for(let i=0;i<10;i++){const mark=el('span',`${Math.round(span*i/10)}s`);mark.style.left=`${i*10}%`;ruler.append(mark);}$('timeline').append(ruler);
  const lanes=[{label:'大阶段 · 预计',items:rs.filter(r=>r.kind==='stage')}];
  for(const anchor of new Set(rs.filter(r=>r.kind==='mechanic').map(r=>r.anchor))) {
    const items=rs.filter(r=>r.anchor===anchor);lanes.push({label:`${items[0].label} · 固定参考 / 人工校准`,items});
  }
  for(const lane of lanes){const track=el('div');track.className='track';const label=el('span',lane.label);label.className='track-label';track.append(label);for(const r of lane.items){const block=el('div',`#${r.occurrence} ${r.at}s`);block.title=`${r.label} / ${r.evidence||'manual_estimate'}`;block.className=`region ${r.kind==='mechanic'?'mechanic':''}`;block.style.left=`${r.at/span*100}%`;block.style.width=`${Math.max(1,(Math.min(r.end,span)-r.at)/span*100)}%`;track.append(block);}$('timeline').append(track);}
  const spellTracks=new Map();
  for(const row of d.rows){
    let track=spellTracks.get(row.spellID);
    if(!track){track=el('div');track.className='track';const title=el('span',spellNames[row.spellID]||`技能 ${row.spellID}`);title.className='track-label';track.append(title);spellTracks.set(row.spellID,track);$('timeline').append(track);}
    if(row.absolute!==null){const point=el('button',`${row.absolute}s`);point.className='point';point.title=`拖动 ${spellNames[row.spellID]||row.spellID} · ${row.absolute} 秒`;point.style.left=`${row.absolute/span*100}%`;point.onpointerdown=e=>{point.setPointerCapture(e.pointerId);};point.onpointermove=e=>{if(point.hasPointerCapture(e.pointerId)){const box=track.getBoundingClientRect();point.style.left=`${Math.max(0,Math.min(100,(e.clientX-box.left)/box.width*100))}%`;}};point.onpointerup=e=>{if(!point.hasPointerCapture(e.pointerId))return;point.releasePointerCapture(e.pointerId);const box=track.getBoundingClientRect();run(()=>commit(move(d,row.id,Math.max(0,Math.min(span,(e.clientX-box.left)/box.width*span)))));};track.append(point);}
    const card=el('article');card.className='rule';
    const top=el('div');top.className='rule-top';const name=el('strong',spellNames[row.spellID]||`技能 ${row.spellID}`);name.className='action-label';top.append(name);const order=el('span',`#${row.id}`);order.className='rule-order';top.append(order);card.append(top);
    const fields=el('div');fields.className='rule-fields';const timeField=el('label','开战后秒数');timeField.className='field';const timeInput=input(row.absolute,at=>commit(move(d,row.id,at)));timeInput.setAttribute('aria-label',`第 ${row.id} 条提醒时间`);timeField.append(timeInput);fields.append(timeField);
    const region=rs.find(r=>r.anchor===row.anchor&&r.occurrence===row.occurrence);
    const description=el('p',row.error||`${region?`${region.label} · 第 ${row.occurrence} 次 · ${row.offset<0?'提前':'之后'} ${Math.abs(row.offset)} 秒`:'开战计时'}。${row.timing==='signal'?'等待实时信号':'按开战后的固定时间提醒'}。`);description.className=row.error?'error':'binding-description';fields.append(description);card.append(fields);
    const options=el('div');options.className='rule-options';options.append(el('span',`来源 P${row.source.phase} + ${row.source.time}s · ${row.manual?'手动锁定':'自动建议'}`));const reset=el('button',row.manual?'恢复自动绑定':'锁定此安排');reset.className='secondary-button';reset.onclick=()=>run(()=>{const n=structuredClone(d);n.rows.find(r=>r.id===row.id).manual=!row.manual;commit(rebind(n));});options.append(reset);card.append(options);$('arrangements').append(card);
    const tr=el('tr');const source=el('td',`P${row.source.phase} + ${row.source.time}s / ${row.spellID}\n${row.source.tag??'个人记录'}`);source.title=row.source.raw;tr.append(source);
    const lock=el('button',row.manual?'手动锁定 · 恢复自动':'自动绑定 · 锁定');
    lock.onclick=()=>run(()=>{const n=structuredClone(d),r=n.rows.find(r=>r.id===row.id);r.manual=!r.manual;commit(rebind(n));});source.append(lock);
    const change=(key,value)=>{
      const n=structuredClone(d),r=n.rows.find(r=>r.id===row.id);r[key]=value;r.manual=true;
      if(key==='offset'||key==='occurrence'){
        const region=regions(n).find(region=>region.anchor===r.anchor&&region.occurrence===r.occurrence);
        if(r.anchor==='start')r.absolute=r.offset;
        else if(region){r.absolute=Math.round((region.at+r.offset)*10)/10;if(r.timing==='fixed')r.fallback=r.absolute;}
      }
      if(key==='fallback'&&r.timing==='fixed')r.absolute=value;
      commit(n);
    };
    const add=control=>{const td=el('td');td.append(control);tr.append(td);};
    add(input(row.absolute,at=>commit(move(d,row.id,at))));
    const anchor=el('select');for(const value of new Set(['start',...rs.map(r=>r.anchor)])){const opt=el('option',value);opt.value=value;anchor.append(opt);}anchor.value=row.anchor||'start';anchor.onchange=()=>run(()=>{const n=structuredClone(d),r=n.rows.find(r=>r.id===row.id);r.anchor=anchor.value;r.manual=true;r.timing=r.anchor==='start'?'auto':'fixed';r.occurrence=1;const region=regions(n).find(region=>region.anchor===r.anchor);r.offset=Math.round((r.absolute-(region?.at||0))*10)/10;r.fallback=r.anchor==='start'?undefined:r.absolute;commit(n);});add(anchor);
    add(input(row.occurrence,v=>change('occurrence',v)));add(input(row.offset,v=>change('offset',v)));
    const timing=el('select');for(const [value,label] of [['fixed','固定兜底（非实测）'],['signal','实时信号（LIVE未测）'],['auto','开战']]){const o=el('option',label);o.value=value;timing.append(o);}timing.value=row.timing||'fixed';timing.onchange=()=>run(()=>change('timing',timing.value));add(timing);
    add(input(row.fallback,v=>change('fallback',v)));add(input(row.window,v=>change('window',v)));
    if(row.error){source.append(el('p',row.error));source.className='error';}$('rows').append(tr);
  }
}
for(const spec of SPECS){const option=el('option',`${spec.classLabel} · ${spec.label}`);option.value=spec.id;$('spec').append(option);}$('spec').value='252';
$('spec').onchange=()=>{if(history.value)run(()=>commit({...history.value,specID:Number($('spec').value)}));};
$('import').onclick=()=>{
  try{const draft=parseNSRT($('note').value,Number($('spec').value));commit(draft);message('importStatus',`导入成功：乌拉特克 · ${draft.difficulty==='heroic'?'英雄':'史诗'} · ${draft.rows.length} 条提醒。${draft.rows.some(r=>r.error)?'请补充阶段起点。':'可以调整时间，也可直接生成。'}`);message('status','导入成功，点击“生成字符串”即可带进游戏。');}
  catch(e){message('importStatus',`导入失败：${e.message}${history.value?'。原有安排保持不变。':''}`,true);}
};
for(const command of ['undo','redo'])$(command).onclick=()=>{history[command]();render();invalidate();message('status',command==='undo'?'已撤销，可继续编辑。':'已重做，可继续编辑。');};
$('calibrate').onclick=()=>run(()=>commit(calibrate(history.value,JSON.parse($('calibration').value))));
$('export').onclick=()=>{try{$('output').value=exportTimeline(history.value);$('copy').disabled=false;message('status',`已生成 ${history.value.rows.length} 条提醒。点击复制，然后在游戏 /nr 中粘贴。`);}catch(e){message('status',e.message,true);}};
$('copy').onclick=async()=>{try{await navigator.clipboard.writeText($('output').value);message('status','已复制。在游戏输入 /nr，粘贴后保存并启用。');}catch{$('output').focus();$('output').select();message('status','浏览器未允许自动复制，已选中字符串，请按 Ctrl+C。');}};
$('draft').onclick=()=>run(()=>{if(!history.value)throw Error('请先导入');const url=URL.createObjectURL(new Blob([JSON.stringify(history.value,null,2)],{type:'application/json'}));const link=el('a');link.href=url;link.download='nextreminders-raid-draft.json';link.click();URL.revokeObjectURL(url);});
$('restore').onchange=async()=>{try{const file=$('restore').files[0];if(!file||file.size>500000)throw Error('草稿过大或未选择');const d=JSON.parse(await file.text());if(typeof d.original!=='string'||!Array.isArray(d.rows)||d.rows.length>100)throw Error('草稿结构无效');regions(d);commit(d);}catch(e){$('status').textContent=e.message;}};
render();
$('import').disabled=false;$('import').textContent='导入并生成时间轴';message('importStatus','等待粘贴个人安排。');
