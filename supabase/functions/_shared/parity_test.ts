// Teste de paridade: as fórmulas da Edge Function precisam bater com as do jogo (GDScript).
// Gere a referência:  godot --headless --path . -s tools/parity_ref.gd
// Rode:               deno run --allow-read supabase/functions/_shared/parity_test.ts
import * as L from "./logic.ts";
const ref = JSON.parse(await Deno.readTextFile(new URL("./parity_ref.json", import.meta.url)));
let fails = 0;
const near = (a: number, b: number, eps: number, msg: string) => {
  if (Math.abs(a - b) > eps) { fails++; console.error("FALHOU", msg, a, b); }
};
for (const l in ref.xp) near(L.xpToNext(+l), ref.xp[l], 0.5, `xp_to_next ${l}`);
for (const l in ref.gold) near(L.goldForKill(+l), ref.gold[l], 0.5, `gold ${l}`);
for (const hid in ref.kills) {
  const r = ref.kills[hid];
  const s = L.computeStats("fogo_1", L.stageForLevel("fogo_1", r.level), r.level, 2, false);
  const f = Array(r.n).fill(s);
  near(L.estimateKills(f, L.D.hunts[hid]).kills_per_hour, r.kph, r.kph * 0.001 + 0.01, `kills/h ${hid}`);
}
for (const e of ref.essence) near(L.essenceValue(e.in[0], e.in[1], e.in[2], e.in[3], e.in[4]), e.v, 0.5, `essence ${e.in}`);
for (const r of ref.reach) near(L.maxReachableLevel(r.in[0], r.in[1]), r.v, 0, `reach ${r.in}`);
for (const d of ref.daily) {
  const b = L.dailyBossDef(d.in[0], d.in[1]);
  if (b.form !== d.form) { fails++; console.error("FALHOU chefe diário", d.in, b.form, d.form); }
  near(b.hp, d.hp, d.hp * 0.0001, `hp chefe diário ${d.in}`);
}
for (const q of ref.quality) {
  const st = L.computeStats("luz_2", L.stageForLevel("luz_2", 77), 77, 0, q.shiny, q.q);
  near(st.atk, q.atk, 0.01, `atk com qualidade ${q.q}`);
  near(L.essenceValue("luz_2", L.stageForLevel("luz_2", 77), 77, 0, q.shiny, q.q), q.ess, 0.5, `essência com qualidade ${q.q}`);
}
for (const m of ref.mastery) {
  const b = L.masteryBonuses(m.in);
  for (const k of L.MASTERY_STATS) near(b[k], m.b[k], 1e-6, `marcos ${k}`);
  const st = L.computeStats("terra_1", 3, 90, 0, false, 40, b);
  for (const k of ["hp", "atk", "def", "spd", "crit"]) near((st as any)[k], m.stats[k], 1e-3, `stats com marcos ${k}`);
}
console.log(fails ? `${fails} falhas` : "paridade GDScript x TypeScript OK");
if (fails) Deno.exit(1);
