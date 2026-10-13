// Browser draft storage, shared by the redesigned planner and its compatibility checks.
import {newDungeon,validateDungeon,SPECS,DUNGEONS} from './plan.mjs';
export const draftKey=(specID,dungeonID)=>`nr-dungeon:${specID}:${dungeonID}`;
export function loadDraft(storage,specID,dungeonID){
  let next=newDungeon(specID,dungeonID);
  let raw=null;
  try{
    raw=storage?.getItem(draftKey(specID,dungeonID));
    const p=JSON.parse(raw);
    if(p&&p.specID===specID&&p.dungeonID===dungeonID){
      validateDungeon(p,true);
      return {...p,plans:next.plans.map(b=>p.plans.find(v=>v.encounterID===b.encounterID)||b)};
    }
  }catch{}
  if(!raw){
    for(const p of next.plans){
      try{
        const old=JSON.parse(storage?.getItem(`nr-plan:${specID}:${p.encounterID}:mythic`));
        if(old){validateDungeon({...next,plans:[old]});Object.assign(p,old);}
      }catch{}
    }
  }
  return next;
}
export function saveDraft(storage,draft){
  validateDungeon(draft,true);
  if(!storage)throw Error('浏览器无法保存草稿，请先生成并复制方案。');
  storage.setItem(draftKey(draft.specID,draft.dungeonID),JSON.stringify(draft));
}
export function lastContext(storage){
  try{const p=JSON.parse(storage?.getItem('nr-last-context'));if(SPECS.some(s=>s.id===p?.specID)&&DUNGEONS.some(d=>d.id===p?.dungeonID))return p;}catch{}
  return {specID:252,dungeonID:2813};
}
export function rememberContext(storage,draft){
  try{storage?.setItem('nr-last-context',JSON.stringify({specID:draft.specID,dungeonID:draft.dungeonID}));}catch{}
}
