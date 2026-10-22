#!/usr/bin/env python3
"""Lista todos os textos Loc.t("...") do código (chaves de tradução em PT-BR)."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pat = re.compile(r'Loc\.t\("((?:[^"\\]|\\.)*)"\)')
keys = []
for d, _, fs in os.walk(os.path.join(ROOT, "src")):
    for f in fs:
        if f.endswith(".gd"):
            for m in pat.finditer(open(os.path.join(d, f), encoding="utf-8").read()):
                k = m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
                if k not in keys:
                    keys.append(k)
if __name__ == "__main__":  # noqa
    for k in keys:
        print(repr(k))
    print(len(keys), file=sys.stderr)
