// Regras autoritativas do servidor — espelho de src/core/formulas.gd, src/progression/*.gd,
// src/loot/*.gd, src/essence/essence_logic.gd e src/network/server_logic.gd.
// Os dados vêm de gamedata.json (gerado por tools/export_server_data.gd).
// deno-lint-ignore-file no-explicit-any
import G from "./gamedata.json" with { type: "json" };

export const D: any = G;
export const C: any = D.config;

// ------------------------------------------------------------ RNG
export function rand(): number {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return a[0] / 4294967296;
}
export function randInt(lo: number, hi: number): number {
  return lo + Math.floor(rand() * (hi - lo + 1));
}
export function newId(prefix: string): string {
  const a = new Uint8Array(8);
  crypto.getRandomValues(a);
  return prefix + Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
}

// ------------------------------------------------------------ tipos
export function typeMult(att: string, def: string): number {
  const n = D.types.length;
  const a = D.types.indexOf(att), d = D.types.indexOf(def);
  if (a < 0 || d < 0) return 1;
  if (d === (a + 1) % n) return D.strong_mult;
  if (d === (a - 1 + n) % n) return D.weak_mult;
  return 1;
}

// ------------------------------------------------------------ fórmulas
export const levelMult = (l: number) => 1 + C.stat_growth_per_level * (Math.max(l, 1) - 1);

export const qualityMult = (q: number) => 1 + (C.quality?.max_bonus ?? 0.3) * Math.min(1, Math.max(0, q / 100));

export function rollQuality(shiny: boolean): number {
  const q = C.quality ?? {};
  if (shiny) {
    const mn = q.shiny_min ?? 50;
    return mn + Math.round((100 - mn) * Math.pow(rand(), 1.3));
  }
  return Math.round(100 * Math.pow(rand(), q.exponent ?? 1.8));
}

export function rawStats(formId: string, level: number, shiny = false, quality = 0) {
  const f = D.forms[formId];
  const fam = D.families[f.family];
  const lm = levelMult(level), sm = C.stage_mult[f.stage - 1], ssm = C.stage_spd_mult[f.stage - 1];
  const sh = (1 + (shiny ? C.shiny_stat_bonus : 0)) * qualityMult(quality);
  return { hp: fam.base.hp * lm * sm * sh, atk: fam.base.atk * lm * sm * sh, def: fam.base.def * lm * sm * sh, spd: fam.base.spd * ssm * sh, rng: fam.base.rng };
}

export function enemyStats(formId: string, level: number, world = 1) {
  const s: any = rawStats(formId, level);
  const m1 = C.enemy_mods;
  const m2 = world === 2 ? (C.world2.enemy_mods ?? m1) : m1;
  const t = world === 2 ? Math.min(1, Math.max(0, (level - C.world2.start) / (C.world2.mods_ramp_levels ?? 30))) : 0;
  for (const k of ["hp", "atk", "def"]) s[k] *= m1[k] + (m2[k] - m1[k]) * t;
  return s;
}

export function killsForLevel(level: number): number {
  const x = C.xp;
  let k = x.kills_min + x.kills_a * Math.pow(level, x.kills_p);
  const late = level - x.late_start;
  if (late > 0) k *= 1 + x.late_slope * late;
  const early = x.early_levels ?? 0;
  if (level < early) {
    const a = x.early_mult_start ?? 1;
    k *= a + (1 - a) * ((level - 1) / (early - 1));
  }
  return k;
}
export const xpForKill = (l: number) => Math.floor(C.xp.kill_base * Math.pow(Math.max(l, 1), C.xp.kill_q));
export const xpToNext = (l: number) => (l >= C.max_level ? 0 : Math.ceil(killsForLevel(l) * xpForKill(l)));
export const goldForKill = (l: number) => Math.floor(C.gold.kill_base * Math.pow(Math.max(l, 1), C.gold.kill_q)) + 1;

export const damageRaw = (atk: number, def: number, p: number) => (atk <= 0 ? 0 : (atk * p * atk) / (atk + Math.max(def, 0)));
export const expectedDamage = (atk: number, def: number, p: number, tm: number, crit: number) =>
  Math.max(1, damageRaw(atk, def, p) * tm) * (1 + crit * (C.combat.crit_mult - 1));
export const attackInterval = (spd: number) => (C.combat.base_attack_interval * 100) / Math.max(spd, 10);
export const enemyAttackInterval = (spd: number) => (C.combat.enemy_attack_interval * 100) / Math.max(spd, 10);

export function stageForLevel(familyId: string, level: number): number {
  const ev = D.families[familyId].evo_levels ?? C.evolution_levels;
  if (level >= ev[1]) return 3;
  if (level >= ev[0]) return 2;
  return 1;
}

export function computeStats(familyId: string, stage: number, level: number, stars: number, shiny: boolean, quality = 0) {
  const fid = `${familyId}_${stage}`;
  const raw = rawStats(fid, level, shiny, quality);
  const starMult = 1 + C.stars.stat_bonus_per_star * stars;
  let up = 0;
  for (const s of C.stars.ability_upgrade_stars) if (stars >= s) up++;
  return {
    type: D.families[familyId].type, hp: raw.hp * starMult, atk: raw.atk * starMult, def: raw.def * starMult,
    spd: raw.spd * (1 + 0.02 * stars), crit: C.combat.crit_chance, lifesteal: 0, type_dmg: {} as Record<string, number>,
    ability_power_mult: 1 + C.stars.ability_power_per_upgrade * up, ability_cd_mult: 1 - C.stars.ability_cd_per_upgrade * up,
  };
}

export function fightingCount(mainLevel: number, size: number) {
  let n = 1;
  if (mainLevel >= C.party.unlock_3) n = 3;
  else if (mainLevel >= C.party.unlock_2) n = 2;
  return Math.max(1, Math.min(n, Math.max(1, size)));
}

// ------------------------------------------------------------ taxa de abates (KillRate.estimate)
export function enemyProfile(hunt: any) {
  const acc = { hp: 0, atk: 0, def: 0, spd: 0 };
  const types: Record<string, number> = {};
  let tw = 0;
  for (const m of hunt.monsters) {
    const w = m.weight ?? 1;
    const s = enemyStats(m.form, hunt.level, hunt.world);
    acc.hp += s.hp * w; acc.atk += s.atk * w; acc.def += s.def * w; acc.spd += s.spd * w;
    const t = D.forms[m.form].type;
    types[t] = (types[t] ?? 0) + w;
    tw += w;
  }
  tw = tw || 1;
  for (const k of Object.keys(acc) as (keyof typeof acc)[]) acc[k] /= tw;
  for (const t in types) types[t] /= tw;
  return { ...acc, types };
}

export function estimateKills(fighters: any[], hunt: any) {
  const kr = C.killrate, cb = C.combat;
  if (!fighters.length) return { kills_per_hour: 0 };
  const e = enemyProfile(hunt);
  let dps = 0, partyHp = 0, partyDef = 0, incoming = 0;
  for (const f of fighters) {
    let perHit = 0;
    for (const t in e.types) {
      const tm = typeMult(f.type, t) * (1 + (f.type_dmg?.[t] ?? 0) / 100);
      perHit += expectedDamage(f.atk, e.def, 1, tm, f.crit) * e.types[t];
      incoming += (typeMult(t, f.type) * e.types[t]) / fighters.length;
    }
    const ab = 1 + (kr.ability_dps_bonus * (f.ability_power_mult ?? 1)) / Math.max(0.3, f.ability_cd_mult ?? 1);
    dps += (perHit / attackInterval(f.spd)) * ab;
    partyHp += f.hp;
    partyDef += f.def / fighters.length;
  }
  const ttk = e.hp / Math.max(dps, 0.001);
  const travel = kr.travel_seconds * Math.sqrt(16 / Math.max(4, hunt.density ?? 16)) * Math.pow(kr.extra_fighter_travel_mult, fighters.length - 1);
  let cycle = ttk + travel;
  const enemyDps = expectedDamage(e.atk, partyDef, 1, incoming, cb.crit_chance) / enemyAttackInterval(e.spd);
  const engaged = kr.engaged_enemies * (1 + 0.15 * (fighters.length - 1));
  const dmg = enemyDps * engaged * ttk;
  let heal = partyHp * cb.regen_pct_per_sec * cycle;
  for (const f of fighters) heal += (dmg / fighters.length) * (f.lifesteal ?? 0);
  const net = dmg - heal;
  let deaths = 0;
  if (dmg > partyHp) deaths = dmg / partyHp;
  else if (net > 0) deaths = net / partyHp;
  cycle += deaths * (cb.revive_seconds + ttk);
  let kph = 3600 / Math.max(cycle, 0.5);
  if (dmg > partyHp) kph *= (partyHp / dmg) * 0.25;
  return { kills_per_hour: Math.min(kph, kr.max_kills_per_hour) };
}

// ------------------------------------------------------------ itens e loot
export function rarityIdx(id: string) {
  return C.rarities.findIndex((r: any) => r.id === id);
}

export function rollServerRarity(mult = 1): string {
  for (let i = C.rarities.length - 1; i >= 0; i--) {
    const r = C.rarities[i];
    if (!r.server) continue;
    if (rand() < r.chance * mult) return r.id;
  }
  return "";
}

export function pickBase(drops: any[]): string {
  if (!drops?.length) return "";
  const total = drops.reduce((a, d) => a + d.weight, 0);
  let r = rand() * total;
  for (const d of drops) { r -= d.weight; if (r <= 0) return d.base; }
  return drops[drops.length - 1].base;
}

export function createItem(baseId: string, rarity: string, bound: boolean) {
  const n = C.rarities[rarityIdx(rarity)]?.affixes ?? 0;
  const pool = [...D.affixes];
  const ri = rarityIdx(rarity);
  const affixes: any[] = [];
  for (let i = 0; i < n && pool.length; i++) {
    const idx = Math.floor(rand() * pool.length);
    const a = pool.splice(idx, 1)[0];
    const t = Math.min(1, Math.max(0, rand() * 0.7 + (ri - 3) * 0.15));
    const aff: any = { id: a.id, v: Math.round(a.min + (a.max - a.min) * t) };
    if (a.per_type) aff.t = D.types[Math.floor(rand() * D.types.length)];
    affixes.push(aff);
  }
  return { uid: newId(bound ? "l" : "s"), base: baseId, rarity, enh: 0, affixes, bound, locked: false };
}

export function sellPrice(item: any): number {
  const b = D.item_bases[item.base];
  if (!b) return 0;
  const ic = C.items;
  let p = ic.sell_base * (1 + ic.sell_per_level * b.level) * C.rarities[rarityIdx(item.rarity)].sell_mult;
  p *= 1 + 0.25 * (item.enh ?? 0);
  return Math.round(p);
}
export const shopPrice = (baseId: string) => Math.floor(sellPrice({ base: baseId, rarity: "comum", enh: 0 }) * C.shop.price_mult);

export function binomial(n: number, p: number): number {
  if (n <= 0 || p <= 0) return 0;
  if (n < 200) { let k = 0; for (let i = 0; i < n; i++) if (rand() < p) k++; return k; }
  const mean = n * p;
  if (mean < 30) {
    const L = Math.exp(-mean); let k = 0; let prod = rand();
    while (prod > L && k < n) { k++; prod *= rand(); }
    return k;
  }
  const sd = Math.sqrt(mean * (1 - p));
  const u = 1 - rand(), v = rand();
  const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  return Math.min(n, Math.max(0, Math.round(mean + sd * z)));
}

export function worldDrops(types: string[], level: number) {
  let tier = 1;
  for (const tr of D.item_tiers) if (tr.level <= level) tier = tr.tier;
  const out: any[] = [];
  for (const t of types) for (const tt of [tier - 1, tier]) {
    if (tt < 1) continue;
    for (const s of D.item_slots) {
      const id = `${s.id}_${t}_t${tt}`;
      if (D.item_bases[id]) out.push({ base: id, weight: tt === tier ? 3 : 1 });
    }
  }
  return out;
}

// ------------------------------------------------------------ essência
export function essenceValue(familyId: string, stage: number, level: number, stars: number, shiny: boolean, quality = 0) {
  const e = C.essence;
  let v = e.stage_base[Math.min(3, Math.max(1, stage)) - 1] * (1 + level / e.level_div);
  v *= D.families[familyId]?.essence_mult ?? 1;
  v *= 1 + 0.2 * stars;
  v *= 1 + quality / 100;
  if (shiny) v *= e.shiny_mult;
  return Math.round(v);
}

export function enhanceCost(item: any) {
  const b = D.item_bases[item.base];
  const tier = b?.tier ?? 1, enh = item.enh ?? 0;
  return {
    essence_type: b?.type ?? "agua",
    essence: Math.floor(C.enhance.essence_cost_per_tier * tier * (enh + 1)),
    gold: Math.floor(C.enhance.gold_cost_per_tier * tier * Math.pow(enh + 1, 1.5)),
  };
}

// ------------------------------------------------------------ validação de nível
export function maxReachableLevel(from: number, seconds: number): number {
  const ac = C.anti_cheat;
  let lvl = from, remaining = seconds;
  while (lvl < C.max_level) {
    const xph = xpForKill(lvl + 10) * 1500 * ac.xp_rate_tolerance * C.ads.xp_boost_mult * 1.6;
    const need = (xpToNext(lvl) / xph) * 3600;
    if (need > remaining) break;
    remaining -= need;
    lvl++;
  }
  return lvl;
}

export const weekId = (t: number) => Math.floor((t + 3 * 86400) / 604800);
export const dayId = (t: number) => Math.floor(t / 86400);

// Chefe Diário: rotação determinística entre as formas adultas (mesma regra do ServerLogic.gd)
export function dailyBossDef(day: number, level: number) {
  const adults = Object.values(D.forms).filter((f: any) => f.stage === 3).map((f: any) => f.form_id);
  const formsOrdered = (D.form_order ?? adults) as string[];
  const form = formsOrdered[(day * 7 + 3) % formsOrdered.length];
  const cfg = C.daily_boss;
  const lvl = Math.min(Math.max(level, 5), C.max_level);
  const st = enemyStats(form, lvl, 1);
  return { form, type: D.forms[form].type, level: lvl, day, hp: st.hp * cfg.hp_mult, def: st.def * cfg.def_mult };
}
