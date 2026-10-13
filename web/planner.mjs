import {SPECS,DUNGEONS,newDungeon,eventOptions,generateDungeon,actionName} from './plan.mjs';
import {loadDraft,saveDraft,lastContext,rememberContext} from './drafts.mjs';
import {BURST_CATALOG,burstSpell,burstSpellsForSpec} from './spells.mjs';
const $=id=>document.getElementById(id);
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let storage=null;try{storage=window.localStorage;}catch{}
const initial=lastContext(storage);
let draft=loadDraft(storage,initial.specID,initial.dungeonID),bossID=draft.plans[0].encounterID,dirty=false,generated=null;
const current=()=>draft.plans.find(p=>p.encounterID===bossID);
const tank=[250,581,104,268,66,73],healer=[105,1468,270,65,256,257,264],melee=[251,252,577,103,255,269,70,259,260,261,263,71,72];
const roleFor=id=>tank.includes(id)?'tank':healer.includes(id)?'healer':melee.includes(id)?'melee':'ranged';
let role=roleFor(draft.specID);
const roles=[['tank','坦克'],['healer','治疗'],['melee','近战'],['ranged','远程']];
const dungeonSlugs=['murder-row','altar-of-fangs','temple-of-sethraliss','den-of-nalorakk','the-blinding-vale','voidscar-arena','ruby-life-pools','kings-rest'];
const dungeonEnglish=['Murder Row','Altar of Fangs','Temple of Sethraliss','Den of Nalorakk','The Blinding Vale','Voidscar Arena','Ruby Life Pools',"Kings’ Rest"];
const bossSlugs={3101:'kystia-manaheart',3102:'zaen-bladesorrow',3103:'xathuux-the-annihilator',3105:'lithiel-cinderfury',3456:'ravi',3457:'the-writhing-coil',3458:'zuljan',2124:'adderis-and-aspix',2125:'merektha',2126:'galvazzt',2127:'avatar-of-sethraliss',3207:'the-hoardmonger',3208:'sentinel-of-winter',3209:'nalorakk',3199:'lightblossom-trinity',3200:'ikuzz-the-light-hunter',3201:'lightwarden-ruia',3202:'ziekket',3285:'tazrah',3286:'atroxus',3287:'charonus',2609:'melidrussa-chillworn',2606:'kokia-blazehoof',2623:'kyrakka-and-erkhart-stormvein',2139:'the-golden-serpent',2142:'mchimba-the-embalmer',2140:'the-council-of-tribes',2143:'dazar-the-first-king'};
let assets={specs:[],bosses:[]};
try{const response=await fetch('./assets.json');if(!response.ok)throw Error('asset catalog');assets=await response.json();}catch{}
const specAsset=s=>assets.specs.find(a=>a.href.split('?')[0]===`/spec-benchmark/${s.className}/${s.specName}`);
const dungeonAsset=d=>assets.bosses.find(a=>a.id==='d-'+dungeonSlugs[DUNGEONS.indexOf(d)]);
const bossImage=(id,d)=>assets.bosses.find(a=>a.id==='b-'+bossSlugs[id])?.local||dungeonAsset(d)?.local||'assets/nextreminders-logo-v2.png';
const specName=s=>`${s.label} ${s.classLabel}`;
function status(text,error=false){$('status').textContent=text;$('status').classList.toggle('error',error);}
function clearOutput(){generated=null;$('output').value='';$('output').hidden=true;$('outputEmpty').hidden=false;$('copy').disabled=true;}
function invalidate(){dirty=true;clearOutput();$('draftState').textContent='待重新生成';status('配置已改变，请重新生成字符串。');renderStats();}
function changeContext(specID,dungeonID){
  if(specID===draft.specID&&dungeonID===draft.dungeonID)return;
  if(dirty&&!confirm('当前副本的草稿尚未保存，切换后会丢失这些改动。继续吗？'))return;
  draft=loadDraft(storage,specID,dungeonID);bossID=draft.plans[0].encounterID;role=roleFor(specID);dirty=false;clearOutput();rememberContext(storage,draft);render();status('设置完成后点击生成。');
}
function renderStats(){
  const plans=draft.plans.filter(p=>p.rows.length);$('configuredCount').textContent=plans.length;$('totalRows').textContent=plans.reduce((n,p)=>n+p.rows.length,0);$('rowCount').textContent=`${current().rows.length} 条`;
  $('draftState').textContent=generated?'已生成':dirty?'未保存':'尚未生成';
  const s=SPECS.find(s=>s.id===draft.specID);$('exportSpecIcon').src=specAsset(s)?.local||'assets/nextreminders-logo-v2.png';$('exportSpecName').textContent=s.label;$('exportDungeonName').textContent=draft.name;
  for(const button of $('bosses').children){const p=draft.plans.find(p=>p.encounterID===Number(button.dataset.boss));button.querySelector('small').textContent=p.rows.length?`${p.rows.length} 条提醒`:'未配置';}
  $('editorNote').textContent=dirty?'草稿尚未保存，离开前可点击右上角“保存草稿”。':'切换首领会保留其他首领的配置。草稿只保存在本机浏览器。';
}
function render(){
  const s=SPECS.find(s=>s.id===draft.specID),d=DUNGEONS.find(d=>d.id===draft.dungeonID),b=d.bosses.find(b=>b[0]===bossID),index=d.bosses.indexOf(b);
  $('selectedIcon').src=specAsset(s)?.local||'assets/nextreminders-logo-v2.png';$('selectedName').textContent=specName(s);$('selectedEnglish').textContent=`${s.specName} ${s.className.replace(/([a-z])([A-Z])/g,'$1 $2')}`;
  $('spellCatalogStatus').textContent=`已内置 ${BURST_CATALOG.specs.length} 个专精的常用爆发技能，本专精 ${burstSpellsForSpec(draft.specID).length} 个。按当前天赋选择，不会自动添加提醒。`;
  $('roles').innerHTML=roles.map(([id,label])=>`<button data-role="${id}" aria-pressed="${role===id}">${label}<span class="role-count">${SPECS.filter(s=>roleFor(s.id)===id).length}</span></button>`).join('');
  for(const button of $('roles').children)button.onclick=()=>{role=button.dataset.role;render();};
  const visible=SPECS.filter(s=>roleFor(s.id)===role);$('specCount').textContent=`${visible.length} 个专精`;
  $('specIcons').innerHTML=visible.map(s=>`<button class="spec-button" style="--class-color:${escape(specAsset(s)?.color||'#9299ac')}" data-spec="${s.id}" title="${specName(s)}" aria-label="${specName(s)}" aria-pressed="${draft.specID===s.id}"><img src="${specAsset(s)?.local||'assets/nextreminders-logo-v2.png'}" alt=""></button>`).join('');
  for(const button of $('specIcons').children)button.onclick=()=>changeContext(Number(button.dataset.spec),draft.dungeonID);
  $('dungeons').innerHTML=DUNGEONS.map(d=>`<button class="dungeon-tab" data-dungeon="${d.id}" aria-pressed="${d.id===draft.dungeonID}"><img src="${dungeonAsset(d)?.local||'assets/nextreminders-logo-v2.png'}" alt=""><span>${escape(d.name)}</span></button>`).join('');
  for(const button of $('dungeons').children)button.onclick=()=>changeContext(draft.specID,Number(button.dataset.dungeon));
  $('dungeonImage').src=dungeonAsset(d)?.local||'assets/nextreminders-logo-v2.png';$('dungeonName').textContent=d.name;$('dungeonSubtitle').textContent=`${dungeonEnglish[DUNGEONS.indexOf(d)]} · ${d.bosses.length} 位首领`;$('bossTotal').textContent=`${d.bosses.length} 位`;
  $('bosses').innerHTML=d.bosses.map(([id,name])=>`<button class="boss-button" data-boss="${id}" aria-pressed="${id===bossID}"><img src="${bossImage(id,d)}" alt=""><span class="boss-info"><strong>${escape(name)}</strong><small></small></span></button>`).join('');
  for(const button of $('bosses').children)button.onclick=()=>{bossID=Number(button.dataset.boss);render();};
  $('bossImage').src=bossImage(bossID,d);$('bossName').textContent=b[1];$('bossNumber').textContent=`BOSS ${String(index+1).padStart(2,'0')}`;
  const events=eventOptions(bossID,'mythic');$('mechanismChips').innerHTML=events.map(e=>`<span class="chip">${escape(e[1])}</span>`).join('');
  $('mechanismHelp').textContent=events.length>1?'开战从首领战开始计时；机制事件从所选事件触发时计时。例如易伤开始后 3 秒提醒，延后填 3。特殊事件识别仍需在游戏中核对。':'这只首领目前可配置开战后的提醒。延后秒数从首领战开始计算。';
  renderRows();renderStats();
}
function field(label,id,content){return `<div class="field"><label for="${id}">${label}</label>${content}</div>`;}
function spellPicker(row,index){
  if(row.type!=='spell')return '';
  const spells=burstSpellsForSpec(draft.specID);
  return `<details class="spell-picker" ${!row.value?'open':''}><summary>选择内置爆发技能 <span>${spells.length} 个</span></summary><div class="burst-grid">${spells.map(s=>`<button type="button" class="spell-pick ${row.value===s.id?'is-selected':''}" data-spell="${s.id}" aria-label="选择 ${escape(s.name)}" aria-pressed="${row.value===s.id}" title="${escape(s.note||s.nameEN)}"><img src="${s.image}" alt=""><span><strong>${escape(s.name)}</strong><small>${s.primarySpecs.includes(draft.specID)?'主要爆发 · ':''}${s.talent?'可选天赋':'技能'} · ${s.id}</small></span></button>`).join('')}</div><p>目录包含可选天赋，按你的当前天赋选择。也可以在下方手动填写其他技能编号。</p></details>`;
}
function renderRows(){
  const rows=current().rows,events=eventOptions(bossID,'mythic');$('empty').hidden=rows.length>0;
  $('rows').innerHTML=rows.map((r,i)=>{
    const readyAllowed=r.type==='spell'&&r.occurrence===1;
    const name=r.type==='spell'&&!r.value?'请选择爆发技能':actionName(r),counts=r.anchor==='start'?[1]:[...Array.from({length:20},(_,n)=>n+1),'every'];
    return `<article class="rule" data-row="${i}">
      <div class="rule-top"><img class="rule-icon" src="${r.type==='spell'&&burstSpell(r.value)?burstSpell(r.value).image:specAsset(SPECS.find(s=>s.id===draft.specID))?.local||'assets/nextreminders-logo-v2.png'}" alt=""><div><div class="action-label">${escape(name)}</div><div class="action-meta">${r.type==='text'?'文字提醒':r.type==='slot'?'饰品栏位':r.type==='item'?'物品编号':'技能编号'} ${r.type==='text'?'':escape(r.value||'待选择')}</div></div><span class="rule-order">${String(i+1).padStart(2,'0')}</span><button class="remove" aria-label="删除第 ${i+1} 条提醒">×</button></div>
      ${spellPicker(r,i)}
      <details class="action-editor" ${!r.value&&r.type!=='spell'?'open':''}><summary>${r.type==='spell'?'手动输入编号 / 更换提醒类型':'设置提醒动作'}</summary><div class="advanced-fields">
        ${field('提醒类型',`type-${i}`,`<select id="type-${i}" data-field="type">${[['spell','技能'],['item','物品'],['slot','饰品栏位'],['text','文字']].map(([k,n])=>`<option value="${k}" ${r.type===k?'selected':''}>${n}</option>`).join('')}</select>`)}
        ${field(r.type==='text'?'提醒文字':r.type==='slot'?'饰品栏位':'技能 / 物品编号',`value-${i}`,r.type==='slot'?`<select id="value-${i}" data-field="value"><option value="13" ${r.value===13?'selected':''}>上槽（13）</option><option value="14" ${r.value===14?'selected':''}>下槽（14）</option></select>`:`<input id="value-${i}" data-field="value" ${r.type==='text'?'':'type="number" min="1" step="1"'} value="${escape(r.value||'')}" placeholder="自行填写">`)}
      </div></details>
      <div class="rule-fields">
        ${field('触发事件',`event-${i}`,`<select id="event-${i}" data-field="anchor">${events.map(e=>`<option value="${e[0]}" ${e[0]===r.anchor?'selected':''}>${escape(e[1])}</option>`).join('')}</select>`)}
        ${field('第几次',`count-${i}`,`<select id="count-${i}" data-field="occurrence">${counts.map(n=>`<option value="${n}" ${n===r.occurrence?'selected':''}>${n==='every'?'每次':`第 ${n} 次`}</option>`).join('')}</select>`)}
        ${field('延后',`delay-${i}`,`<div class="unit-field"><input id="delay-${i}" data-field="time" type="number" min="0" max="3600" step="0.1" value="${r.time}"><span>秒</span></div>`)}
        ${field('保留',`window-${i}`,`<div class="unit-field"><input id="window-${i}" data-field="window" type="number" min="0.1" max="60" step="0.1" value="${r.window}"><span>秒</span></div>`)}
      </div>
      <label class="ready-option ${r.after?'is-on':''} ${readyAllowed?'':'is-disabled'}" for="ready-${i}"><input id="ready-${i}" data-field="after" type="checkbox" role="switch" ${r.after?'checked':''} ${readyAllowed?'':'disabled'}><span class="switch-track" aria-hidden="true"></span><span class="ready-copy"><strong>之后每次冷却结束，都提醒我</strong><span>${readyAllowed?'按这条提醒用过一次技能后，之后每次冷却好了都会显示提醒；开启游戏内语音时，同时播报。':'仅用于技能的第一次事件提醒；物品、文字和重复事件不支持。'}</span></span><span class="ready-state">${r.after?'已开启':'未开启'}</span></label>
      <details class="wait-details"><summary>事件前的等待文字 <span>可选</span></summary>${field('等待文字',`hold-${i}`,`<input id="hold-${i}" data-field="hold" value="${escape(r.hold)}" placeholder="例如：留着，等第一次易伤">`)}</details>
    </article>`;
  }).join('');
  for(const card of $('rows').children){
    const rowIndex=Number(card.dataset.row),r=rows[rowIndex];
    for(const button of card.querySelectorAll('[data-spell]'))button.onclick=()=>{const id=Number(button.dataset.spell);if(r.value===id)return;r.value=id;invalidate();renderRows();renderStats();};
    card.querySelector('.remove').onclick=()=>{rows.splice(rowIndex,1);invalidate();renderRows();renderStats();};
    for(const input of card.querySelectorAll('[data-field]')){
      input.addEventListener('input',()=>{
        const key=input.dataset.field;
        if(key==='after'){if(input.checked)r.after='ready';else delete r.after;card.querySelector('.ready-option').classList.toggle('is-on',input.checked);card.querySelector('.ready-state').textContent=input.checked?'已开启':'未开启';}
        else if(key==='type'){r.type=input.value;r.value=r.type==='text'?'':r.type==='slot'?13:0;delete r.after;}
        else if(key==='value'){
          r.value=r.type==='text'?input.value:Number(input.value);
          card.querySelector('.action-label').textContent=r.type==='spell'&&!r.value?'请选择爆发技能':actionName(r);
          card.querySelector('.action-meta').textContent=(r.type==='text'?'文字提醒':r.type==='slot'?'饰品栏位':r.type==='item'?'物品编号':'技能编号')+(r.type==='text'?'':' '+(r.value||'待选择'));
          card.querySelector('.rule-icon').src=r.type==='spell'&&burstSpell(r.value)?burstSpell(r.value).image:specAsset(SPECS.find(s=>s.id===draft.specID))?.local||'assets/nextreminders-logo-v2.png';
        }
        else if(key==='occurrence'){r.occurrence=input.value==='every'?'every':Number(input.value);if(r.occurrence!==1)delete r.after;}
        else if(key==='time'||key==='window')r[key]=Number(input.value);
        else r[key]=input.value;
        if(r.anchor==='start')r.occurrence=1;
        invalidate();
      });
      input.addEventListener('change',()=>{if(input.dataset.field!=='after'){renderRows();renderStats();}});
    }
  }
}
function add(){if(current().rows.length>=100){status('每只首领最多 100 条提醒。',true);return;}current().rows.push({type:'spell',value:0,anchor:'start',occurrence:1,time:0,window:10,hold:''});invalidate();renderRows();renderStats();const card=$('rows').lastElementChild;(card.querySelector('.spell-pick')||card.querySelector('[data-field="value"]')).focus();}
$('add').onclick=add;$('emptyAdd').onclick=add;
$('mechanismToggle').onclick=()=>{$('mechanismHelp').hidden=!$('mechanismHelp').hidden;$('mechanismToggle').setAttribute('aria-expanded',String(!$('mechanismHelp').hidden));};
$('generate').onclick=()=>{clearOutput();try{generated=generateDungeon(draft);$('output').value=generated.text;$('output').hidden=false;$('outputEmpty').hidden=true;$('copy').disabled=false;renderStats();status(`已生成 ${generated.bundle.plans.length} 只首领的方案，可以复制。`);}catch(e){renderStats();status(e.message,true);}};
$('copy').onclick=async()=>{const text=generated?.text;if(!text)return;try{await navigator.clipboard.writeText(text);status('已复制，在游戏 /nr 粘贴即可。');}catch{$('output').focus();$('output').select();status('请按 Ctrl+C 复制选中的字符串。');}};
$('save').onclick=()=>{try{saveDraft(storage,draft);rememberContext(storage,draft);dirty=false;renderStats();status(generated?'草稿已保存，可以复制当前方案。':'草稿已保存，复制前请先生成字符串。');}catch(e){status(e.message||'本机存储不可用。',true);}};
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
window.nrPlanner={getDraft:()=>structuredClone(draft),getGenerated:()=>generated?structuredClone(generated):null};
render();
