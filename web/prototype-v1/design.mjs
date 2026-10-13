// In-memory UI prototype. One design requested; no game writes or saved browser drafts.
import {SPECS,DUNGEONS,newDungeon,eventOptions,generateDungeon,actionName} from '../plan.mjs';
const assets=await fetch('./assets.json').then(r=>r.json());
const $=id=>document.getElementById(id);
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const tank=[250,581,104,268,66,73],healer=[105,1468,270,65,256,257,264],melee=[251,252,577,103,255,269,70,259,260,261,263,71,72];
const roleFor=id=>tank.includes(id)?'tank':healer.includes(id)?'healer':melee.includes(id)?'melee':'ranged';
const roles=[['tank','坦克'],['healer','治疗'],['melee','近战'],['ranged','远程']];
const dungeonSlugs=['murder-row','altar-of-fangs','temple-of-sethraliss','den-of-nalorakk','the-blinding-vale','voidscar-arena','ruby-life-pools','kings-rest'];
const dungeonEnglish=['Murder Row','Altar of Fangs','Temple of Sethraliss','Den of Nalorakk','The Blinding Vale','Voidscar Arena','Ruby Life Pools',"Kings’ Rest"];
const sourceDungeon=i=>assets.bosses.find(b=>b.id==='d-'+dungeonSlugs[i]);
const portraits=assets.bosses.filter(b=>b.id.startsWith('b-'));
const bossSlugs={3101:'kystia-manaheart',3102:'zaen-bladesorrow',3103:'xathuux-the-annihilator',3105:'lithiel-cinderfury',3456:'ravi',3457:'the-writhing-coil',3458:'zuljan',2124:'adderis-and-aspix',2125:'merektha',2126:'galvazzt',2127:'avatar-of-sethraliss',3207:'the-hoardmonger',3208:'sentinel-of-winter',3209:'nalorakk',3199:'lightblossom-trinity',3200:'ikuzz-the-light-hunter',3201:'lightwarden-ruia',3202:'ziekket',3285:'tazrah',3286:'atroxus',3287:'charonus',2609:'melidrussa-chillworn',2606:'kokia-blazehoof',2623:'kyrakka-and-erkhart-stormvein',2139:'the-golden-serpent',2142:'mchimba-the-embalmer',2140:'the-council-of-tribes',2143:'dazar-the-first-king'};
const specAsset=s=>assets.specs.find(a=>a.href.split('?')[0]===`/spec-benchmark/${s.className}/${s.specName}`);
const bossAsset=(name,id)=>portraits.find(b=>b.id==='b-'+bossSlugs[id])||portraits.find(b=>b.name?.replace(/[’']/g,'').toLowerCase()===name.replace(/[’']/g,'').toLowerCase());
const specName=s=>`${s.label} ${s.classLabel}`;
const cache=new Map();
let specID=251,dungeonID=2813,bossID=3101,role='melee',sample=true;
const draft=()=>{const key=`${specID}:${dungeonID}`;if(!cache.has(key))cache.set(key,newDungeon(specID,dungeonID));return cache.get(key);};
const plan=()=>draft().plans.find(p=>p.encounterID===bossID);
function applyExample(){
  specID=251;dungeonID=2813;bossID=3101;role='melee';
  const d=newDungeon(specID,dungeonID);d.plans[0].rows=[
    {type:'spell',value:51271,anchor:'start',occurrence:1,time:0,window:10,hold:''},
    {type:'spell',value:1249658,anchor:'vuln',occurrence:1,time:3,window:10,hold:'等第一次易伤'},
    {type:'spell',value:51271,anchor:'vuln',occurrence:1,time:3,window:10,hold:''},
  ];cache.set('251:2813',d);sample=true;
}
function status(message,error=false){$('status').textContent=message;$('status').classList.toggle('error',error);}
function invalidate(){ $('output').value='';$('output').hidden=true;$('outputEmpty').hidden=false;$('copy').disabled=true;status('设置完成后点击生成');renderStats(); }
function setImage(element,path){element.src=path||sourceDungeon(DUNGEONS.findIndex(d=>d.id===dungeonID))?.local;}
function renderStats(){
  const plans=draft().plans.filter(p=>p.rows.length);$('configuredCount').textContent=plans.length;$('totalRows').textContent=plans.reduce((n,p)=>n+p.rows.length,0);
  $('rowCount').textContent=`${plan().rows.length} 条`;
  const s=SPECS.find(s=>s.id===specID);setImage($('exportSpecIcon'),specAsset(s)?.local);$('exportSpecName').textContent=s.label;$('exportDungeonName').textContent=draft().name;
  for(const button of $('bosses').children){const p=draft().plans.find(p=>p.encounterID===Number(button.dataset.boss));button.querySelector('small').textContent=p.rows.length?`${p.rows.length} 条提醒`:'未配置';}
}
function render(){
  const s=SPECS.find(s=>s.id===specID),d=DUNGEONS.find(d=>d.id===dungeonID),di=DUNGEONS.indexOf(d),b=d.bosses.find(b=>b[0]===bossID),bi=d.bosses.indexOf(b);
  setImage($('selectedIcon'),specAsset(s)?.local);$('selectedName').textContent=specName(s);$('selectedEnglish').textContent=`${s.specName} ${s.className.replace(/([a-z])([A-Z])/g,'$1 $2')}`;
  $('roles').innerHTML=roles.map(([id,label])=>`<button data-role="${id}" aria-pressed="${role===id}">${label}<span class="role-count">${SPECS.filter(s=>roleFor(s.id)===id).length}</span></button>`).join('');
  for(const b of $('roles').children)b.onclick=()=>{role=b.dataset.role;render();};
  const visible=SPECS.filter(s=>roleFor(s.id)===role);$('specCount').textContent=`${visible.length} 个专精`;
  $('specIcons').innerHTML=visible.map(s=>`<button class="spec-button" style="--class-color:${specAsset(s)?.color||'#9299ac'}" data-spec="${s.id}" title="${specName(s)}" aria-label="${specName(s)}" aria-pressed="${specID===s.id}"><img src="${specAsset(s)?.local}" alt=""></button>`).join('');
  for(const b of $('specIcons').children)b.onclick=()=>{specID=Number(b.dataset.spec);sample=false;invalidate();render();};
  $('dungeons').innerHTML=DUNGEONS.map((d,i)=>`<button class="dungeon-tab" data-dungeon="${d.id}" aria-pressed="${d.id===dungeonID}"><img src="${sourceDungeon(i)?.local}" alt=""><span>${escape(d.name)}</span></button>`).join('');
  for(const b of $('dungeons').children)b.onclick=()=>{dungeonID=Number(b.dataset.dungeon);bossID=DUNGEONS.find(d=>d.id===dungeonID).bosses[0][0];sample=false;invalidate();render();};
  setImage($('dungeonImage'),sourceDungeon(di)?.local);$('dungeonName').textContent=d.name;$('dungeonSubtitle').textContent=`${dungeonEnglish[di]} · ${d.bosses.length} 位首领`;$('bossTotal').textContent=`${d.bosses.length} 位`;
  $('bosses').innerHTML=d.bosses.map(([id,name],i)=>`<button class="boss-button" data-boss="${id}" aria-pressed="${id===bossID}"><img src="${bossAsset(name,id)?.local||sourceDungeon(di)?.local}" alt=""><span class="boss-info"><strong>${escape(name)}</strong><small></small></span></button>`).join('');
  for(const button of $('bosses').children)button.onclick=()=>{bossID=Number(button.dataset.boss);render();};
  setImage($('bossImage'),bossAsset(b[1],bossID)?.local||sourceDungeon(di)?.local);$('bossName').textContent=b[1];$('bossNumber').textContent=`BOSS ${String(bi+1).padStart(2,'0')}`;
  const events=eventOptions(bossID,'mythic');$('mechanismChips').innerHTML=events.map(e=>`<span class="chip">${escape(e[1])}</span>`).join('');
  $('mechanismHelp').textContent=events.length>1?'开战：从首领战开始计时。机制事件：从所选事件开始计时。例如易伤开始后 3 秒提醒，延后填写 3。事件识别仍需在游戏中核对。':'这只首领目前可配置开战后的提醒。延后秒数从首领战开始计算。';
  $('sampleBadge').hidden=!sample;$('editorNote').textContent=sample?'当前为填写示例，用来查看布局。':'切换首领会保留本页其他首领的配置。';
  renderRows();renderStats();
}
function renderRows(){
  const rows=plan().rows,events=eventOptions(bossID,'mythic');$('empty').hidden=rows.length>0;
  $('rows').innerHTML=rows.map((r,i)=>`<article class="rule" data-row="${i}">
    <div class="rule-top"><img class="rule-icon" src="${r.value===1249658?'assets/breath.jpg':r.value===51271?'assets/pillar.jpg':specAsset(SPECS.find(s=>s.id===specID))?.local}" alt=""><div><div class="action-label">${escape(actionName(r))}</div><div class="action-meta">${r.type==='text'?'文字提醒':r.type==='slot'?'饰品栏位':r.type==='item'?'物品编号':'技能编号'} ${r.type==='text'?'':escape(r.value||'待填写')}</div></div><span class="rule-order">${String(i+1).padStart(2,'0')}</span><button class="remove" aria-label="删除第 ${i+1} 条提醒">×</button></div>
    <div class="rule-fields">
      <div class="field"><label for="event-${i}">触发事件</label><select id="event-${i}" data-field="anchor">${events.map(e=>`<option value="${e[0]}" ${e[0]===r.anchor?'selected':''}>${escape(e[1])}</option>`).join('')}</select></div>
      <div class="field"><label for="count-${i}">第几次</label><select id="count-${i}" data-field="occurrence">${[1,2,3,'every'].map(n=>`<option value="${n}" ${n===r.occurrence?'selected':''}>${n==='every'?'每次':n==='1'?'第一次':`第 ${n} 次`}</option>`).join('')}</select></div>
      <div class="field"><label for="delay-${i}">延后</label><div class="unit-field"><input id="delay-${i}" data-field="time" type="number" min="0" max="3600" step="0.1" value="${r.time}"><span>秒</span></div></div>
      <div class="field"><label for="window-${i}">保留</label><div class="unit-field"><input id="window-${i}" data-field="window" type="number" min="0.1" max="60" step="0.1" value="${r.window}"><span>秒</span></div></div>
    </div>
    <div class="rule-options"><label class="ready-label"><input data-field="after" type="checkbox" ${r.after?'checked':''} ${r.type!=='spell'||r.occurrence!==1?'disabled':''}>首次使用后，冷却好了再提醒</label><details class="advanced"><summary>动作与等待文字</summary><div class="advanced-fields">
      <div class="field"><label for="type-${i}">提醒类型</label><select id="type-${i}" data-field="type">${[['spell','技能'],['item','物品'],['slot','饰品栏位'],['text','文字']].map(([k,n])=>`<option value="${k}" ${r.type===k?'selected':''}>${n}</option>`).join('')}</select></div>
      <div class="field"><label for="value-${i}">${r.type==='text'?'提醒文字':'编号 / 栏位'}</label><input id="value-${i}" data-field="value" value="${escape(r.value||'')}" placeholder="自行填写"></div>
      <div class="field" style="grid-column:1/-1"><label for="hold-${i}">事件前的等待文字（可选）</label><input id="hold-${i}" data-field="hold" value="${escape(r.hold)}" placeholder="例如：留着，等第一次易伤"></div>
    </div></details></div>
  </article>`).join('');
  for(const card of $('rows').children){
    const r=rows[Number(card.dataset.row)];
    card.querySelector('.remove').onclick=()=>{rows.splice(Number(card.dataset.row),1);invalidate();render();};
    for(const input of card.querySelectorAll('[data-field]')){
      input.addEventListener('input',()=>{
        const field=input.dataset.field;
        if(field==='after'){if(input.checked)r.after='ready';else delete r.after;}
        else if(field==='type'){r.type=input.value;r.value=r.type==='text'?'':r.type==='slot'?13:0;delete r.after;}
        else if(field==='value')r.value=r.type==='text'?input.value:Number(input.value);
        else if(field==='occurrence')r.occurrence=input.value==='every'?'every':Number(input.value);
        else if(field==='time'||field==='window')r[field]=Number(input.value);
        else r[field]=input.value;
        if(r.anchor==='start')r.occurrence=1;if(r.occurrence!==1)delete r.after;
        invalidate();
      });
      input.addEventListener('change',()=>{renderRows();renderStats();});
    }
  }
}
function add(){plan().rows.push({type:'spell',value:0,anchor:'start',occurrence:1,time:0,window:10,hold:''});invalidate();render();const fields=$('rows').lastElementChild;fields.querySelector('details').open=true;fields.querySelector('[data-field="value"]').focus();}
$('add').onclick=add;$('emptyAdd').onclick=add;
$('example').onclick=()=>{applyExample();invalidate();render();};
$('mechanismToggle').onclick=()=>{$('mechanismHelp').hidden=!$('mechanismHelp').hidden;$('mechanismToggle').setAttribute('aria-expanded',String(!$('mechanismHelp').hidden));};
$('generate').onclick=()=>{try{const result=generateDungeon(draft());$('output').value=result.text;$('output').hidden=false;$('outputEmpty').hidden=true;$('copy').disabled=false;status('已生成，可复制到 NextReminders');}catch(e){invalidate();status(e.message,true);}};
$('copy').onclick=async()=>{try{await navigator.clipboard.writeText($('output').value);status('已复制，请在游戏中粘贴');}catch{$('output').focus();$('output').select();status('请按 Ctrl+C 复制选中的字符串');}};
applyExample();render();
