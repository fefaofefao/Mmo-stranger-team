#!/usr/bin/env python3
"""Gera locale/translations.csv a partir de tools/i18n_table.py e confere se todo Loc.t("...") do código tem tradução.
Uso: python3 tools/build_translations.py"""
import csv, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from i18n_table import T
from extract_strings import keys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
missing = [k for k in keys if k not in T]
for k in missing:
    print("SEM TRADUÇÃO:", repr(k))
for k, (en, es) in T.items():
    if k.count("%") != en.count("%") or k.count("%") != es.count("%"):
        print("PLACEHOLDERS DIFERENTES:", repr(k))
with open(os.path.join(ROOT, "locale", "translations.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["keys", "en", "es"])
    for k, (en, es) in T.items():
        w.writerow([k, en, es])
print("%d chaves, %d sem tradução" % (len(T), len(missing)))
sys.exit(1 if missing else 0)
