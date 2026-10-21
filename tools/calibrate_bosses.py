#!/usr/bin/env python3
"""Calibra hp_mult/atk_mult dos chefes (data/challenges.json) para que um inicial NEUTRO
no nível do desafio + 3, com equipamento Incomum do tier, vença em ~80s com folga.
Depois valide com:  godot --headless --path . -s tools/challenge_sim.gd"""
import json, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = json.load(open(f"{R}/data/config.json"))
fams = {f["id"]: f for f in json.load(open(f"{R}/data/families.json"))["families"]}
chs = json.load(open(f"{R}/data/challenges.json"))
types = [t["id"] for t in json.load(open(f"{R}/data/types.json"))["types"]]
g = cfg["stat_growth_per_level"]; sm = cfg["stage_mult"]; em = cfg["enemy_mods"]; cb = cfg["combat"]
lm = lambda l: 1 + g * (l - 1)
def stage(l): return 3 if l >= 35 else (2 if l >= 16 else 1)
def dmg(a, d): return a * a / (a + d)
TARGET_FIGHT, TARGET_SURVIVE = 75.0, 150.0
tiers = [(1,1),(2,12),(3,25),(4,40),(5,60),(6,80)]
for c in chs["challenges"]:
    L = c["level"] + 3
    bt = c["type"]
    neutral = types[(types.index(bt) + 3) % 9]
    fam = next(f for f in fams.values() if f["starter"] and f["type"] == neutral)
    st = stage(L); b = fam["base"]; stars = min(5, L // 25); smult = 1 + 0.06 * stars
    tier_lvl = max(t[1] for t in tiers if t[1] <= L)
    ihp = 18 * lm(tier_lvl) * 1.2; iatk = 3 * lm(tier_lvl) * 1.2; idef = 2.6 * lm(tier_lvl) * 1.2
    php = b["hp"] * lm(L) * sm[st-1] * smult + ihp
    patk = b["atk"] * lm(L) * sm[st-1] * smult + iatk
    pdef = b["def"] * lm(L) * sm[st-1] * smult + idef
    bfam = fams[c["boss_form"].rsplit("_", 1)[0]]; bst = int(c["boss_form"].rsplit("_", 1)[1]); bl = c["boss_level"]
    bb = bfam["base"]
    bhp = bb["hp"] * lm(bl) * sm[bst-1] * em["hp"]
    batk = bb["atk"] * lm(bl) * sm[bst-1] * em["atk"]
    bdef = bb["def"] * lm(bl) * sm[bst-1] * em["def"] * c["def_mult"]
    pdps = dmg(patk, bdef) / cb["base_attack_interval"] * 1.35
    hp_mult = TARGET_FIGHT * pdps / bhp
    adds = 1.0 + (0.45 if "summon" in c["mechanics"] else 0) + (0.25 if "aoe" in c["mechanics"] else 0)
    # sobrevivência: php / (boss_dps*adds - regen) = TARGET_SURVIVE
    need_dps = php / TARGET_SURVIVE + php * cb["regen_pct_per_sec"]
    # boss_dps = dmg(batk*k, pdef)/interval ; resolve k por busca
    lo, hi = 0.05, 5.0
    for _ in range(60):
        k = (lo + hi) / 2
        bd = dmg(batk * k, pdef) / cb["enemy_attack_interval"] * adds
        if bd > need_dps: hi = k
        else: lo = k
    c["hp_mult"] = round(hp_mult, 2)
    c["atk_mult"] = round(k, 2)
    print(c["id"], "L", L, "hp_mult", c["hp_mult"], "atk_mult", c["atk_mult"])
json.dump(chs, open(f"{R}/data/challenges.json", "w"), ensure_ascii=False, indent=1)
