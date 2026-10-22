// Edge Function "game": ponto único de entrada das regras autoritativas.
// Deploy:  supabase functions deploy game
// Requer as variáveis padrão SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY (já injetadas pelo Supabase).
// deno-lint-ignore-file no-explicit-any
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as L from "../_shared/logic.ts";

const { C, D } = L;
const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: any, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
const ok = (extra: any = {}) => ({ ok: true, ...extra });
const err = (error: string) => ({ ok: false, error });
const nowS = () => Date.now() / 1000;
const ts = (iso: string | null) => (iso ? new Date(iso).getTime() / 1000 : 0);
const iso = (s: number) => new Date(s * 1000).toISOString();

type Ctx = { uid: string; user: any; userClient: any; player: any; dirty: Record<string, any> };

function wallet(p: any) {
  return { gold: Number(p.gold), essences: p.essences ?? {} };
}

async function loadPlayer(uid: string) {
  const { data } = await admin.from("players").select("*").eq("id", uid).maybeSingle();
  if (data) return data;
  const essences: Record<string, number> = {};
  for (const t of D.types) essences[t] = 0;
  const { data: created, error } = await admin.from("players").insert({ id: uid, essences }).select("*").single();
  if (error) throw error;
  return created;
}

// grava as mudanças no jogador com controle de concorrência otimista
async function savePlayer(ctx: Ctx) {
  if (!Object.keys(ctx.dirty).length) return;
  const { data, error } = await admin.from("players").update({ ...ctx.dirty, version: ctx.player.version + 1 })
    .eq("id", ctx.uid).eq("version", ctx.player.version).select("version");
  if (error) throw error;
  if (!data?.length) throw new Error("conflito de concorrência, tente novamente");
}

function set(ctx: Ctx, k: string, v: any) {
  ctx.player[k] = v;
  ctx.dirty[k] = v;
}
function addGold(ctx: Ctx, n: number) {
  set(ctx, "gold", Number(ctx.player.gold) + Math.floor(n));
}
function addEss(ctx: Ctx, t: string, n: number) {
  const e = { ...(ctx.player.essences ?? {}) };
  e[t] = (e[t] ?? 0) + n;
  set(ctx, "essences", e);
}

async function partyUpperStats(ctx: Ctx, party: any[]) {
  const ids = party.map((p) => p.server_id).filter(Boolean);
  const { data: recs } = ids.length ? await admin.from("monsters").select("*").in("server_id", ids).eq("owner", ctx.uid) : { data: [] };
  const byId: Record<string, any> = {};
  for (const r of recs ?? []) byId[r.server_id] = r;
  const allowance = C.anti_cheat.gear_allowance ?? 1.8;
  const out: any[] = [];
  for (const pm of party) {
    const rec = byId[pm.server_id];
    const fam = rec?.family ?? pm.family;
    if (!D.families[fam]) continue;
    const lvl = Math.min(pm.level ?? 1, ctx.player.validated_level + 10);
    const stage = Math.max(L.stageForLevel(fam, lvl), pm.stage ?? 1);
    const s: any = L.computeStats(fam, Math.min(stage, 3), lvl, rec?.stars ?? 0, rec?.shiny ?? false, rec?.quality ?? 100, mastery(ctx));
    s.hp *= allowance; s.atk *= allowance; s.def *= allowance; s.spd *= 1.25; s.crit += 0.1;
    out.push(s);
  }
  return out;
}

// Marcos de Caça: abates validados por forma (players.mastery) -> bônus da conta
function mastery(ctx: Ctx) {
  return L.masteryBonuses(ctx.player.mastery ?? {});
}
function addMastery(ctx: Ctx, byForm: Record<string, number>) {
  const m = { ...(ctx.player.mastery ?? {}) };
  for (const f in byForm) m[f] = (m[f] ?? 0) + byForm[f];
  set(ctx, "mastery", m);
}
const goldMult = (ctx: Ctx, goldPct: number) => 1 + Math.min(Math.max(goldPct ?? 0, 0), 100) / 100 + mastery(ctx).gold_pct / 100;

function capStats(upper: any[], client: any[]) {
  return upper.map((u, i) => {
    const s = { ...u };
    const c = client?.[i];
    if (c) for (const k of ["hp", "atk", "def", "spd", "crit"]) if (typeof c[k] === "number") s[k] = Math.min(c[k], u[k]);
    return s;
  });
}

const fighters = (party: any[], stats: any[]) => stats.slice(0, L.fightingCount(party[0]?.level ?? 1, party.length));

async function insertItem(ctx: Ctx, it: any) {
  it.bound = false;
  await admin.from("items").insert({ uid: it.uid, owner: ctx.uid, data: it });
  return it;
}

async function rollRecruit(ctx: Ctx, hunt: any, form: string, shiny: boolean) {
  if (hunt.world !== 1 || !hunt.recruit) return null;
  let ch = C.recruit_chance * (hunt.recruit_mult ?? 1) * (1 + mastery(ctx).recruit_pct / 100);
  if (shiny) ch *= C.shiny_recruit_mult ?? 10;
  if (L.rand() >= ch) return null;
  const f = D.forms[form];
  const rec = { server_id: L.newId("m"), owner: ctx.uid, family: f.family, form, shiny, stars: 0, converted: false, starter: false, quality: L.rollQuality(shiny) };
  await admin.from("monsters").insert(rec);
  return rec;
}

async function bulkKills(ctx: Ctx, hunt: any, kills: number, goldPct: number) {
  const byForm: Record<string, number> = {};
  const tw = hunt.monsters.reduce((a: number, m: any) => a + (m.weight ?? 1), 0);
  let assigned = 0;
  hunt.monsters.forEach((m: any, i: number) => {
    const n = i < hunt.monsters.length - 1 ? Math.round((kills * (m.weight ?? 1)) / tw) : kills - assigned;
    byForm[m.form] = (byForm[m.form] ?? 0) + Math.max(0, n);
    assigned += Math.max(0, n);
  });
  const mb = mastery(ctx);
  const gold = Math.floor(kills * L.goldForKill(hunt.level) * (hunt.gold_mult ?? 1) * goldMult(ctx, goldPct));
  addMastery(ctx, byForm);
  addGold(ctx, gold);
  set(ctx, "npc_budget", Number(ctx.player.npc_budget) + kills * C.anti_cheat.npc_sell_budget_per_kill * (1 + 0.15 * hunt.level));
  const stats = { ...(ctx.player.stats ?? {}) };
  stats.kills = (stats.kills ?? 0) + kills;
  set(ctx, "stats", stats);
  const items: any[] = [];
  for (const r of C.rarities) {
    if (!r.server) continue;
    const n = L.binomial(kills, r.chance * (hunt.rarity_mult ?? 1) * (1 + mb.drop_pct / 100));
    for (let i = 0; i < Math.min(n, 50); i++) items.push(await insertItem(ctx, L.createItem(L.pickBase(hunt.drops), r.id, false)));
  }
  const shinies = L.binomial(kills, C.shiny_chance);
  const recruits: any[] = [];
  if (hunt.world === 1 && hunt.recruit) {
    const ch = C.recruit_chance * (hunt.recruit_mult ?? 1) * (1 + mb.recruit_pct / 100);
    const sr = L.binomial(shinies, Math.min(1, ch * (C.shiny_recruit_mult ?? 10)));
    const nr = L.binomial(kills - shinies, ch);
    const forms = Object.keys(byForm);
    for (let i = 0; i < Math.min(sr + nr, 30); i++) {
      const fid = forms[Math.floor(L.rand() * forms.length)];
      const rec = { server_id: L.newId("m"), owner: ctx.uid, family: D.forms[fid].family, form: fid, shiny: i < sr, stars: 0, converted: false, starter: false, quality: L.rollQuality(i < sr) };
      await admin.from("monsters").insert(rec);
      recruits.push(rec);
    }
  }
  return ok({ kills, kills_by_form: byForm, gold_gained: gold, items, recruits, shinies, wallet: wallet(ctx.player) });
}

function dailyState(ctx: Ctx) {
  const today = L.dayId(nowS());
  let d = ctx.player.daily ?? {};
  if (d.day !== today) d = { day: today, used: 0, tokens: {} };
  return d;
}

// ------------------------------------------------------------------ ações
const actions: Record<string, (ctx: Ctx, a: any) => Promise<any>> = {
  async login(ctx) {
    return ok({ player_id: ctx.uid, name: ctx.player.name, wallet: wallet(ctx.player), google_linked: ctx.player.google_linked });
  },
  async link_google(ctx) {
    const linked = (ctx.user.identities ?? []).some((i: any) => i.provider === "google");
    if (linked) set(ctx, "google_linked", true);
    return ok({ google_linked: linked });
  },
  async set_name(ctx, a) {
    const name = String(a.name ?? "").trim().slice(0, 20);
    if (name.length < 3) return err("Nome muito curto");
    set(ctx, "name", name);
    return ok({ name });
  },
  async get_profile(ctx) {
    const { data: items } = await admin.from("items").select("data").eq("owner", ctx.uid);
    const { data: mons } = await admin.from("monsters").select("*").eq("owner", ctx.uid);
    const { data: sales } = await admin.from("market_sales").update({ notified: true }).eq("seller", ctx.uid).eq("notified", false).select("listing, net");
    const monsters: Record<string, any> = {};
    for (const m of mons ?? []) monsters[m.server_id] = m;
    return ok({ player_id: ctx.uid, name: ctx.player.name, wallet: wallet(ctx.player), items: (items ?? []).map((r: any) => r.data),
      monsters, sales: sales ?? [], server_time: nowS(), google_linked: ctx.player.google_linked, mastery: ctx.player.mastery ?? {} });
  },
  async touch(ctx) {
    set(ctx, "last_seen_at", iso(nowS()));
    return ok();
  },
  async register_starter(ctx, a) {
    const fam = D.families[a.family];
    if (!fam?.starter) return err("Inicial inválido");
    const { data: ex } = await admin.from("monsters").select("*").eq("owner", ctx.uid).eq("starter", true).maybeSingle();
    if (ex) return ok({ monster: ex });
    const rec = { server_id: L.newId("m"), owner: ctx.uid, family: a.family, form: fam.stages[0].form_id, shiny: false, stars: 0, converted: false, starter: true, quality: C.quality?.starter ?? 50 };
    await admin.from("monsters").insert(rec);
    return ok({ monster: rec });
  },
  async spawn_tickets(ctx, a) {
    const n = Math.min(100, Math.max(1, a.n ?? 20));
    if (!D.hunts[a.hunt]) return err("Hunt inválida");
    const rows = [];
    for (let i = 0; i < n; i++) rows.push({ id: L.newId("t"), owner: ctx.uid, hunt: a.hunt, shiny: L.rand() < C.shiny_chance, used: false });
    await admin.from("spawn_tickets").insert(rows);
    return ok({ tickets: rows.map((r) => ({ id: r.id, shiny: r.shiny })) });
  },
  async claim_kills(ctx, a) {
    const hunt = D.hunts[a.hunt];
    if (!hunt) return err("Hunt inválida");
    const t = nowS();
    const elapsed = Math.min(Math.max(t - ts(ctx.player.last_claim_at), 0), C.anti_cheat.claim_max_seconds);
    set(ctx, "last_claim_at", iso(t));
    set(ctx, "last_seen_at", iso(t));
    const party = a.party ?? [];
    const est = L.estimateKills(fighters(party, await partyUpperStats(ctx, party)), hunt);
    const allowed = Math.floor((est.kills_per_hour * elapsed) / 3600 * C.anti_cheat.kill_rate_tolerance) + 3;
    const kills: any[] = (a.kills ?? []).slice(0, allowed);
    const valid = new Set(hunt.monsters.map((m: any) => m.form));
    const lmin = hunt.level - C.enemy_level_spread - 1, lmax = hunt.level + C.enemy_level_spread + 1;
    const tIds = kills.map((k) => k.ticket).filter(Boolean);
    const { data: tks } = tIds.length ? await admin.from("spawn_tickets").select("*").in("id", tIds).eq("owner", ctx.uid).eq("used", false) : { data: [] };
    const tmap: Record<string, any> = {};
    for (const tk of tks ?? []) tmap[tk.id] = tk;
    let gold = 0, shinies = 0, budget = Number(ctx.player.npc_budget);
    const items: any[] = [], recruits: any[] = [], usedT: string[] = [];
    const gm = goldMult(ctx, a.gold_pct ?? 0);
    const luck = 1 + mastery(ctx).drop_pct / 100;
    const byForm: Record<string, number> = {};
    for (const k of kills) {
      if (!valid.has(k.form)) continue;
      byForm[k.form] = (byForm[k.form] ?? 0) + 1;
      const lvl = Math.min(Math.max(k.level ?? hunt.level, lmin), lmax);
      gold += Math.floor(L.goldForKill(lvl) * (hunt.gold_mult ?? 1) * gm);
      budget += C.anti_cheat.npc_sell_budget_per_kill * (1 + 0.15 * lvl);
      let shiny = false;
      const tk = k.ticket && tmap[k.ticket];
      if (tk && tk.hunt === a.hunt) { shiny = tk.shiny; usedT.push(tk.id); delete tmap[k.ticket]; }
      if (shiny) shinies++;
      const rar = L.rollServerRarity((hunt.rarity_mult ?? 1) * luck);
      if (rar) items.push(await insertItem(ctx, L.createItem(L.pickBase(hunt.drops), rar, false)));
      const rec = await rollRecruit(ctx, hunt, k.form, shiny);
      if (rec) recruits.push(rec);
    }
    if (usedT.length) await admin.from("spawn_tickets").update({ used: true }).in("id", usedT);
    addMastery(ctx, byForm);
    addGold(ctx, gold);
    set(ctx, "npc_budget", budget);
    const stats = { ...(ctx.player.stats ?? {}) };
    stats.kills = (stats.kills ?? 0) + kills.length;
    set(ctx, "stats", stats);
    return ok({ accepted: kills.length, rejected: (a.kills ?? []).length - kills.length, gold_gained: gold, wallet: wallet(ctx.player), items, recruits, shinies });
  },
  async claim_offline(ctx, a) {
    const hunt = D.hunts[a.hunt];
    const t = nowS();
    const elapsed = Math.min(Math.max(t - ts(ctx.player.last_seen_at), 0), C.offline.max_hours * 3600);
    set(ctx, "last_seen_at", iso(t));
    set(ctx, "last_claim_at", iso(t));
    const party = a.party ?? [];
    if (!hunt || elapsed < C.offline.min_seconds || !party.length) {
      return ok({ seconds: elapsed, kills: 0, kills_by_form: {}, gold_gained: 0, items: [], recruits: [], shinies: 0, wallet: wallet(ctx.player) });
    }
    const f = fighters(party, capStats(await partyUpperStats(ctx, party), a.stats ?? []));
    const kills = Math.floor((L.estimateKills(f, hunt).kills_per_hour * elapsed) / 3600 * C.offline.efficiency);
    const res = await bulkKills(ctx, hunt, kills, a.gold_pct ?? 0);
    set(ctx, "last_offline", { hunt: a.hunt, kills, doubled: false, t, gold_pct: a.gold_pct ?? 0 });
    return { ...res, seconds: elapsed };
  },
  async double_offline(ctx) {
    const lo = ctx.player.last_offline ?? {};
    if (!lo.hunt || lo.doubled || nowS() - lo.t > 1800) return err("Nada para dobrar");
    set(ctx, "last_offline", { ...lo, doubled: true });
    return await bulkKills(ctx, D.hunts[lo.hunt], lo.kills, lo.gold_pct ?? 0);
  },
  async claim_challenge(ctx, a) {
    const c = D.challenges.find((x: any) => x.id === a.challenge);
    if (!c) return err("Desafio inválido");
    const { data: rec0 } = await admin.from("challenge_records").select("*").eq("owner", ctx.uid).eq("challenge_id", c.id).maybeSingle();
    const rec = rec0 ?? { owner: ctx.uid, challenge_id: c.id, cleared: false, best: 0, last_fail: null, week: 0, week_best: 0 };
    const t = nowS();
    if (!a.won) {
      rec.last_fail = iso(t);
      await admin.from("challenge_records").upsert(rec);
      return ok({ won: false, cooldown: D.challenge_fail_cooldown });
    }
    const seconds = Number(a.seconds ?? 0);
    if (seconds < C.anti_cheat.challenge_min_seconds) return err("Tempo de vitória implausível");
    if ((a.party?.[0]?.level ?? 1) > ctx.player.validated_level + 10) return err("Nível não validado");
    const first = !rec.cleared;
    rec.cleared = true;
    if (!rec.best || seconds < rec.best) rec.best = seconds;
    const wk = L.weekId(t);
    if (rec.week !== wk || !rec.week_best || seconds < rec.week_best) { rec.week = wk; rec.week_best = seconds; }
    await admin.from("challenge_records").upsert(rec);
    const mult = first ? 1 : 0.25;
    const gold = Math.floor(c.rewards.gold * mult);
    addGold(ctx, gold);
    const ess: Record<string, number> = {};
    for (const et in c.rewards.essence) { const n = Math.floor(c.rewards.essence[et] * mult); addEss(ctx, et, n); ess[et] = n; }
    const items: any[] = [];
    if (first) items.push(await insertItem(ctx, L.createItem(L.pickBase(L.worldDrops([c.type], c.level)), c.rewards.item_rarity, false)));
    return ok({ won: true, first, gold_gained: gold, essence_gained: ess, items, best: rec.best, wallet: wallet(ctx.player), unlocks: c.unlocks ?? "" });
  },
  async daily_boss_status(ctx, a) {
    const d = dailyState(ctx);
    const lvl = Math.min(a.level ?? 1, ctx.player.validated_level + 10);
    return ok({ boss: L.dailyBossDef(d.day, lvl), used: d.used, entries: C.daily_boss.entries, resets_in: (d.day + 1) * 86400 - nowS() });
  },
  async daily_boss_start(ctx, a) {
    const d = dailyState(ctx);
    if (d.used >= C.daily_boss.entries) return err("Sem entradas hoje. Volte amanhã!");
    const lvl = Math.min(a.level ?? 1, ctx.player.validated_level + 10);
    const token = L.newId("db");
    d.used += 1;
    d.tokens[token] = { level: lvl, t: nowS(), done: false };
    set(ctx, "daily", d);
    return ok({ token, boss: L.dailyBossDef(d.day, lvl), used: d.used });
  },
  async daily_boss_claim(ctx, a) {
    const d = dailyState(ctx);
    const tk = d.tokens[a.token];
    if (!tk || tk.done) return err("Entrada inválida");
    tk.done = true;
    set(ctx, "daily", d);
    const cfg = C.daily_boss;
    const boss = L.dailyBossDef(d.day, tk.level);
    const seconds = Math.min(Math.max(Number(a.seconds ?? 0), 0), Math.min(nowS() - tk.t + 5, cfg.time_limit + 5));
    const party = a.party ?? [];
    let dps = 0;
    for (const f of fighters(party, await partyUpperStats(ctx, party))) {
      dps += (L.expectedDamage(f.atk, boss.def, 1, L.typeMult(f.type, boss.type), f.crit) / L.attackInterval(f.spd)) * 1.6;
    }
    const maxFrac = Math.min(1, Math.max(0, (dps * seconds * 1.5) / Math.max(1, boss.hp)));
    let frac = Math.min(Math.max(Number(a.fraction ?? 0), 0), maxFrac);
    let won = !!a.won && maxFrac >= 0.95 && seconds >= cfg.min_seconds;
    if (won) frac = 1;
    const rf = cfg.min_reward_fraction + (1 - cfg.min_reward_fraction) * frac;
    const gold = Math.floor(cfg.gold_kills * L.goldForKill(boss.level) * rf);
    const ess = Math.floor((cfg.essence_base + cfg.essence_per_level * boss.level) * rf);
    addGold(ctx, gold);
    addEss(ctx, boss.type, ess);
    const items: any[] = [];
    if (won) {
      let rar = "raro", acc = 0;
      const r = L.rand();
      for (const [id, p] of cfg.item_rarity_roll) { acc += p; if (r < acc) { rar = id; break; } }
      items.push(await insertItem(ctx, L.createItem(L.pickBase(L.worldDrops([boss.type], boss.level)), rar, false)));
    }
    return ok({ won, fraction: frac, gold_gained: gold, essence_type: boss.type, essence_gained: ess, items, wallet: wallet(ctx.player) });
  },
  async challenge_status(ctx) {
    const { data } = await admin.from("challenge_records").select("*").eq("owner", ctx.uid);
    const out: Record<string, any> = {};
    for (const r of data ?? []) out[r.challenge_id] = r;
    return ok({ challenges: out, server_time: nowS() });
  },
  async convert_monster(ctx, a) {
    const { data: rec } = await admin.from("monsters").select("*").eq("server_id", a.server_id).eq("owner", ctx.uid).maybeSingle();
    if (!rec || rec.converted) return err("Monstro inválido");
    if (rec.starter) return err("O inicial não pode ser trocado");
    const level = Math.min(a.level ?? 1, ctx.player.validated_level + 10);
    const stage = Math.min(Math.max(a.stage ?? 1, D.forms[rec.form].stage), 3);
    const amount = L.essenceValue(rec.family, stage, level, rec.stars, rec.shiny, rec.quality ?? 0);
    const t = D.families[rec.family].type;
    const { data: upd } = await admin.from("monsters").update({ converted: true }).eq("server_id", rec.server_id).eq("converted", false).select("server_id");
    if (!upd?.length) return err("Monstro já trocado");
    addEss(ctx, t, amount);
    return ok({ essence_type: t, amount, wallet: wallet(ctx.player) });
  },
  async convert_monsters(ctx, a) {
    const results: any[] = [];
    const totals: Record<string, number> = {};
    for (const e of (a.list ?? []).slice(0, 50)) {
      const r: any = await actions.convert_monster(ctx, e);
      delete r.wallet;
      r.server_id = e.server_id;
      results.push(r);
      if (r.ok) totals[r.essence_type] = (totals[r.essence_type] ?? 0) + r.amount;
    }
    return ok({ results, totals, wallet: wallet(ctx.player) });
  },
  async buy_star(ctx, a) {
    const { data: rec } = await admin.from("monsters").select("*").eq("server_id", a.server_id).eq("owner", ctx.uid).maybeSingle();
    if (!rec || rec.converted) return err("Monstro inválido");
    if (rec.stars >= C.stars.max) return err("Estrelas no máximo");
    const cost = C.stars.cost[rec.stars];
    const t = D.families[rec.family].type;
    if ((ctx.player.essences?.[t] ?? 0) < cost) return err("Essência insuficiente");
    const { data: upd } = await admin.from("monsters").update({ stars: rec.stars + 1 }).eq("server_id", rec.server_id).eq("stars", rec.stars).select("stars");
    if (!upd?.length) return err("Tente novamente");
    addEss(ctx, t, -cost);
    return ok({ stars: rec.stars + 1, wallet: wallet(ctx.player) });
  },
  async spend(ctx, a) {
    const gold = Math.floor(a.gold ?? 0);
    const ess = a.essences ?? {};
    if (gold < 0 || Number(ctx.player.gold) < gold) return err("Ouro insuficiente");
    for (const t in ess) if (ess[t] < 0 || (ctx.player.essences?.[t] ?? 0) < ess[t]) return err("Essência insuficiente");
    addGold(ctx, -gold);
    for (const t in ess) addEss(ctx, t, -Math.floor(ess[t]));
    return ok({ wallet: wallet(ctx.player), reason: a.reason ?? "" });
  },
  async npc_sell(ctx, a) {
    const item = a.item ?? {};
    if (item.locked) return err("Item travado");
    let price = 0;
    if (!item.bound) {
      const { data: row } = await admin.from("items").delete().eq("uid", item.uid).eq("owner", ctx.uid).select("data").maybeSingle();
      if (!row) return err("Item não encontrado no servidor");
      price = L.sellPrice(row.data);
    } else {
      price = Math.min(L.sellPrice(item), Math.floor(Number(ctx.player.npc_budget)));
      set(ctx, "npc_budget", Number(ctx.player.npc_budget) - price);
    }
    addGold(ctx, price);
    return ok({ gold_gained: price, wallet: wallet(ctx.player) });
  },
  async npc_sell_many(ctx, a) {
    const sold: string[] = [];
    let gold = 0;
    for (const it of (a.items ?? []).slice(0, 100)) {
      const r: any = await actions.npc_sell(ctx, { item: it });
      if (r.ok) {
        sold.push(it.uid);
        gold += r.gold_gained;
      }
    }
    return ok({ sold, gold_gained: gold, wallet: wallet(ctx.player) });
  },
  async npc_buy(ctx, a) {
    const b = D.item_bases[a.base];
    if (!b || b.world2_only) return err("Item indisponível");
    const price = L.shopPrice(a.base);
    if (Number(ctx.player.gold) < price) return err("Ouro insuficiente");
    addGold(ctx, -price);
    return ok({ item: L.createItem(a.base, "comum", true), wallet: wallet(ctx.player) });
  },
  async enhance_item(ctx, a) {
    const { data: row } = await admin.from("items").select("*").eq("uid", a.uid).eq("owner", ctx.uid).maybeSingle();
    if (!row) return err("Item não encontrado");
    const it = row.data;
    if ((it.enh ?? 0) >= C.enhance.max) return err("Aprimoramento máximo");
    const cost = L.enhanceCost(it);
    const r = await actions.spend(ctx, { gold: cost.gold, essences: { [cost.essence_type]: cost.essence } });
    if (!r.ok) return r;
    const success = L.rand() < C.enhance.success[it.enh ?? 0];
    if (success) it.enh = (it.enh ?? 0) + 1;
    await admin.from("items").update({ data: it }).eq("uid", it.uid);
    return ok({ success, item: it, wallet: wallet(ctx.player) });
  },
  async sync_save(ctx, a) {
    const s = a.summary ?? {};
    const t = nowS();
    const claimed = Math.floor(s.main_level ?? 1);
    const allowed = L.maxReachableLevel(ctx.player.validated_level, t - ts(ctx.player.validated_at));
    let lvl = claimed, corrected = false;
    if (claimed > allowed) { lvl = allowed; corrected = true; set(ctx, "flagged", (ctx.player.flagged ?? 0) + 1); }
    if (lvl > ctx.player.validated_level) { set(ctx, "validated_level", lvl); set(ctx, "validated_at", iso(t)); }
    else if (claimed <= ctx.player.validated_level) set(ctx, "validated_at", iso(t));
    set(ctx, "last_seen_at", iso(t));
    const stats = { ...(ctx.player.stats ?? {}), level: ctx.player.validated_level, collection: Math.min(Math.max(s.collection ?? 0, 0), Object.keys(D.forms).length) };
    set(ctx, "stats", stats);
    const wk = L.weekId(t);
    if ((ctx.player.weekly?.week ?? -1) !== wk) {
      const { data: rk } = await admin.from("ranking_global").select("*").eq("id", ctx.uid).maybeSingle();
      set(ctx, "weekly", { week: wk, base: { level: stats.level, collection: stats.collection, shinies: rk?.shinies ?? 0, stars: rk?.stars ?? 0 } });
    }
    return ok({ validated_level: ctx.player.validated_level, corrected, allowed_level: allowed });
  },
  async cloud_save_put(ctx, a) {
    const raw = JSON.stringify(a.save ?? {});
    if (raw.length > 2_000_000) return err("Save grande demais");
    set(ctx, "cloud_save", a.save);
    set(ctx, "cloud_saved_at", iso(nowS()));
    return ok({ t: nowS() });
  },
  async cloud_save_get(ctx) {
    return ok({ save: ctx.player.cloud_save ?? {}, t: ts(ctx.player.cloud_saved_at) });
  },
  async ranking_categories() {
    return ok({ categories: ["level", "collection", "shinies", "stars", ...D.challenges.map((c: any) => "challenge_" + c.id)] });
  },
  async rankings(ctx, a) {
    const cat = String(a.category ?? "level");
    const weekly = a.period === "weekly";
    const wk = L.weekId(nowS());
    let entries: any[] = [];
    let isTime = false;
    if (cat.startsWith("challenge_")) {
      isTime = true;
      const cid = cat.slice(10);
      let q = admin.from("challenge_records").select("owner, best, week, week_best, players(name)").eq("challenge_id", cid).eq("cleared", true);
      if (weekly) q = q.eq("week", wk);
      const { data } = await q.order(weekly ? "week_best" : "best", { ascending: true }).limit(200);
      entries = (data ?? []).map((r: any) => ({ id: r.owner, name: r.players?.name ?? "?", value: Number(weekly ? r.week_best : r.best) }));
    } else {
      if (!["level", "collection", "shinies", "stars"].includes(cat)) return err("Categoria inválida");
      const { data } = await admin.from("ranking_global").select("*").order(cat, { ascending: false }).limit(weekly ? 1000 : 200);
      entries = (data ?? []).map((r: any) => ({ id: r.id, name: r.name, value: Number(r[cat]) }));
      if (weekly) {
        const ids = entries.map((e) => e.id);
        const { data: ps } = await admin.from("players").select("id, weekly").in("id", ids);
        const base: Record<string, number> = {};
        for (const p of ps ?? []) base[p.id] = p.weekly?.week === wk ? Number(p.weekly?.base?.[cat] ?? 0) : Infinity;
        entries = entries.map((e) => ({ ...e, value: base[e.id] === Infinity ? 0 : e.value - base[e.id] })).filter((e) => e.value > 0);
        entries.sort((x, y) => y.value - x.value);
      }
    }
    let myRank = -1, myValue = 0;
    entries.forEach((e, i) => { e.rank = i + 1; e.me = e.id === ctx.uid; if (e.me) { myRank = i + 1; myValue = e.value; } delete e.id; });
    return ok({ entries: entries.slice(0, 50), my_rank: myRank, my_value: myValue, is_time: isTime });
  },
  // market: funções Postgres atômicas executadas com o JWT do usuário (auth.uid())
  async market_search(ctx, a) {
    const { data, error } = await ctx.userClient.rpc("market_search", { f: a.filters ?? {} });
    return error ? err(error.message) : data;
  },
  async market_list_item(ctx, a) {
    const { data, error } = await ctx.userClient.rpc("market_list_item", { p_uid: a.uid, p_price: a.price });
    return error ? err(error.message) : data;
  },
  async market_list_essence(ctx, a) {
    const { data, error } = await ctx.userClient.rpc("market_list_essence", { p_type: a.type, p_amount: a.amount, p_price: a.price });
    return error ? err(error.message) : data;
  },
  async market_buy(ctx, a) {
    const { data, error } = await ctx.userClient.rpc("market_buy", { p_listing: Number(a.listing) });
    return error ? err(error.message) : data;
  },
  async market_cancel(ctx, a) {
    const { data, error } = await ctx.userClient.rpc("market_cancel", { p_listing: Number(a.listing) });
    return error ? err(error.message) : data;
  },
  async market_my(ctx) {
    const { data, error } = await ctx.userClient.rpc("market_my");
    return error ? err(error.message) : data;
  },
};

// ações que só leem/escrevem via RPC não devem sobrescrever o jogador com dados antigos
const NO_PLAYER_WRITE = new Set(["market_search", "market_list_item", "market_list_essence", "market_buy", "market_cancel", "market_my", "rankings", "ranking_categories", "challenge_status", "daily_boss_status"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const userClient = createClient(URL, ANON, { global: { headers: { Authorization: auth } }, auth: { persistSession: false } });
    const { data: u, error: ue } = await userClient.auth.getUser();
    if (ue || !u?.user) return json(err("não autenticado"), 401);
    const body = await req.json();
    const fn = actions[body.action];
    if (!fn) return json(err("ação desconhecida: " + body.action), 400);
    const player = await loadPlayer(u.user.id);
    const ctx: Ctx = { uid: u.user.id, user: u.user, userClient, player, dirty: {} };
    const res = await fn(ctx, body.args ?? {});
    if (!NO_PLAYER_WRITE.has(body.action)) await savePlayer(ctx);
    return json({ ...res, server_time: nowS() });
  } catch (e) {
    console.error(e);
    return json(err(String((e as Error)?.message ?? e)), 500);
  }
});
