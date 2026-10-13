// WCL -> NextReminders note. Lorrgs only covers raids; this reads one player's casts in one boss pull straight from
// Warcraft Logs (raid fights and Mythic+ boss pulls alike) and prints NSRT text that /nr imports as-is.
//
//   node tools/wcl_note.mjs top --dungeon "Murder Row" --boss 3101 --class DeathKnight --spec Frost [--rank 1]
//   node tools/wcl_note.mjs top --boss 3492 --class DeathKnight --spec Frost [--difficulty 5]       (raid)
//   node tools/wcl_note.mjs report <code|url> --fight 5 --boss 3101 --player Xmda
// Shared options: --spells 51271,439843 (exact list) | --exclude 47528 | --min-gap 45 | --copy | --list
//
// Time 0 is WCL's start of the boss pull (Mythic+ dungeonPulls / raid fight start), which approximates ENCOUNTER_START.
// Credentials and request pacing come from the rotation-lab skill (configure_wcl.ps1); set ROTATION_LAB_DIR to move it.
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs/promises';
import {execFile} from 'node:child_process';
import {pathToFileURL, fileURLToPath} from 'node:url';

const MYTHIC_PLUS_ZONE = 55;
const DIFFICULTY = {3: 'Normal', 4: 'Heroic', 5: 'Mythic', 10: 'Mythic'};

function parseArgs(argv) {
  const opts = {_: []};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { opts._.push(a); continue; }
    const key = a.slice(2);
    if (key === 'copy' || key === 'list') opts[key] = true;
    else { if (i + 1 >= argv.length) throw Error('缺少参数值：' + a); opts[key] = argv[++i]; }
  }
  return opts;
}

const ids = s => s ? String(s).split(',').map(x => Number(x.trim())).filter(Number.isInteger) : null;
const reportCode = s => (String(s).match(/reports\/([A-Za-z0-9]+)/) || [, s])[1];
const fightFromUrl = s => Number((String(s).match(/[#?&]fight=(\d+)/) || [])[1]) || null;

// Cooldown heuristic: WCL has no cooldown data, so keep spells whose casts are always >= minGap seconds apart.
export function selectSpells(casts, {spells, exclude, minGap = 45}) {
  const bySpell = new Map();
  for (const c of casts) (bySpell.get(c.spellID) || bySpell.set(c.spellID, []).get(c.spellID)).push(c.time);
  const keep = new Set();
  for (const [id, times] of bySpell) {
    if (spells) { if (spells.includes(id)) keep.add(id); continue; }
    if (exclude?.includes(id)) continue;
    let gap = Infinity;
    for (let i = 1; i < times.length; i++) gap = Math.min(gap, times[i] - times[i - 1]);
    if (gap >= minGap) keep.add(id);
  }
  return {bySpell, keep};
}

export function formatNote({encounterID, difficulty, bossName, player, casts, keep, source}) {
  const lines = [`# ${source}`, `EncounterID:${encounterID};Difficulty:${difficulty};Name:${bossName.replace(/[;\n]/g, ' ')};`];
  const tag = player.replace(/[;:\s]/g, '');
  for (const c of casts) if (keep.has(c.spellID))
    lines.push(`ph:1;time:${c.time.toFixed(1)};tag:${tag};spellid:${c.spellID};`);
  return lines.join('\n') + '\n';
}

async function loadSession() {
  const dir = process.env.ROTATION_LAB_DIR || path.join(os.homedir(), '.claude', 'skills', 'rotation-lab');
  const mod = await import(pathToFileURL(path.join(dir, 'api_capture.mjs')).href);
  return mod.session({log: e => console.error('[WCL]', JSON.stringify(e))});
}

async function findDungeon(q, name) {
  if (/^\d+$/.test(name)) return Number(name);
  const data = await q(`query($z:Int!){worldData{zone(id:$z){encounters{id name}}}}`, {z: MYTHIC_PLUS_ZONE});
  const list = data.worldData.zone.encounters;
  const hit = list.filter(e => e.name.toLowerCase().includes(name.toLowerCase()));
  if (hit.length !== 1) throw Error(`--dungeon 需唯一匹配：${list.map(e => `${e.id} ${e.name}`).join(' / ')}`);
  return hit[0].id;
}

async function topRanking(q, opts) {
  const rankEncounter = opts.dungeon ? await findDungeon(q, opts.dungeon) : Number(opts['ranking-id'] || opts.boss);
  const vars = {id: rankEncounter, c: opts.class, s: opts.spec, d: opts.dungeon ? null : Number(opts.difficulty || 5)};
  const want = Number(opts.rank || 1);
  let seen = 0;
  for (let page = 1; page <= 5; page++) {
    const data = await q(`query($id:Int!,$c:String!,$s:String!,$d:Int,$p:Int){worldData{encounter(id:$id){name
      characterRankings(className:$c,specName:$s,difficulty:$d,page:$p)}}}`, {...vars, p: page});
    const enc = data.worldData.encounter;
    if (!enc) throw Error('WCL 没有排行编号 ' + rankEncounter + '（大秘境首领请加 --dungeon）');
    const r = enc.characterRankings;
    // Blizzard leaderboard rows carry no log; only ranks with a report can be read.
    for (const x of r.rankings || []) if (x.report?.code && ++seen === want) {
      console.error(`[排行] ${enc.name} 第 ${want} 份带日志：${x.name}-${x.server?.name} ${x.hardModeLevel ? '+' + x.hardModeLevel : ''}`);
      return {code: x.report.code, fight: x.report.fightID, player: x.name};
    }
    if (!r.hasMorePages) break;
  }
  throw Error('前 5 页排行中没有足够的带日志记录');
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const [mode, target] = opts._;
  if (!['top', 'report'].includes(mode) || !opts.boss) {
    console.error((await fs.readFile(fileURLToPath(import.meta.url), 'utf8')).split('\nimport ')[0]);
    process.exit(2);
  }
  const boss = Number(opts.boss);
  const {query: q} = await loadSession();
  let code, fightID, player;
  if (mode === 'top') {
    if (!opts.class || !opts.spec) throw Error('top 需要 --class 和 --spec（WCL 英文名，如 DeathKnight / Frost）');
    ({code, fight: fightID, player} = await topRanking(q, opts));
  } else {
    code = reportCode(target); fightID = Number(opts.fight) || fightFromUrl(target); player = opts.player;
    if (!code || !fightID || !player) throw Error('report 需要报告代码、--fight 和 --player');
  }

  const meta = (await q(`query($c:String!,$f:[Int]!){reportData{report(code:$c){title
    fights(fightIDs:$f){id name encounterID difficulty keystoneLevel startTime endTime friendlyPlayers
      dungeonPulls{name encounterID startTime endTime kill}}
    masterData{actors(type:"Player"){id name} abilities{gameID name}}}}}`, {c: code, f: [fightID]})).reportData.report;
  const fight = meta?.fights?.[0];
  if (!fight) throw Error(`报告 ${code} 没有战斗 ${fightID}（可能是私有报告）`);
  const pull = fight.encounterID === boss ? fight : fight.dungeonPulls?.find(p => p.encounterID === boss);
  if (!pull) throw Error(`战斗 ${fightID} 里没有首领 ${boss}`);
  const actor = meta.masterData.actors.filter(a => a.name === player && fight.friendlyPlayers.includes(a.id));
  if (actor.length !== 1) throw Error(`该战斗里找不到唯一玩家 ${player}`);

  const casts = [];
  for (let start = pull.startTime; start != null;) {
    const page = (await q(`query($c:String!,$f:[Int]!,$s:Float!,$e:Float!,$src:Int!){reportData{report(code:$c){
      events(fightIDs:$f,startTime:$s,endTime:$e,dataType:Casts,sourceID:$src,limit:10000){data nextPageTimestamp}}}}`,
      {c: code, f: [fightID], s: start, e: pull.endTime, src: actor[0].id})).reportData.report.events;
    // sourceID filter also returns events by others on this player; keep the player's own completed casts.
    for (const e of page.data) if (e.type === 'cast' && e.sourceID === actor[0].id)
      casts.push({spellID: e.abilityGameID, time: (e.timestamp - pull.startTime) / 1000});
    start = page.nextPageTimestamp;
  }
  if (!casts.length) throw Error('这段没有该玩家的施法记录');

  const names = new Map(meta.masterData.abilities.map(a => [a.gameID, a.name]));
  const {bySpell, keep} = selectSpells(casts, {spells: ids(opts.spells), exclude: ids(opts.exclude), minGap: Number(opts['min-gap'] || 45)});
  const duration = ((pull.endTime - pull.startTime) / 1000).toFixed(0);
  console.error(`[战斗] ${pull.name} ${duration} 秒 ${pull.kill ? '击杀' : '未击杀'}；${player} 共 ${casts.length} 次施法，选中 ${keep.size} 个技能：`);
  for (const [id, times] of [...bySpell].sort((a, b) => a[1].length - b[1].length))
    if (opts.list || keep.has(id)) console.error(`  ${keep.has(id) ? '✓' : ' '} ${id} ${names.get(id) || '?'} ×${times.length}  ${times.slice(0, 6).map(t => t.toFixed(0)).join(' ')}`);

  const note = formatNote({encounterID: boss, difficulty: DIFFICULTY[fight.difficulty] || 'Mythic', bossName: pull.name, player, casts, keep,
    source: `WCL ${code} fight ${fightID} ${player} ${fight.keystoneLevel ? '+' + fight.keystoneLevel + ' ' + fight.name : ''}`.trim()});
  process.stdout.write(note);
  if (opts.copy) {
    const tmp = path.join(os.tmpdir(), 'nr-wcl-note.txt');
    await fs.writeFile(tmp, note, 'utf8');
    await new Promise((ok, fail) => execFile('powershell.exe', ['-NoProfile', '-Command',
      'Get-Content -Raw -Encoding UTF8 -LiteralPath $env:NR_NOTE | Set-Clipboard'], {env: {...process.env, NR_NOTE: tmp}, windowsHide: true},
      err => err ? fail(Error('复制到剪贴板失败')) : ok()));
    console.error('[完成] 已复制，游戏里 /nr 粘贴即可');
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main().catch(e => { console.error('错误：' + e.message); process.exit(1); });
