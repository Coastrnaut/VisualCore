#!/bin/sh
# scan-claims.sh — feature 093 (A12-P05) T-A12-503 (FR-A12-506; SC-A12-505; clarification 5). Modelled on
# specs/086-pp-p05-stability/scan-claims.sh. Three checks:
# 1. The Tiny Worlds catalog entry (its registration in Catalog/registrations.json and its entry in
#    Catalog/experiences.json) and docs/apps/tiny-worlds/README.md contain none of the refused claim words
#    (accurate, accuracy, precise, precision, scientific, realistic, real-world, geographic, fps, frames per second,
#    battery, and a millisecond figure such as "16 ms"; whole words, case-insensitive); the README's non-goals line
#    (the line holding "Non-goals:"), which states what the experience does not claim, is exempt.
# 2. Every capability of the registration has a row in the README's "Capabilities and their proof" table.
# 3. Every proving test named in that table ("File.swift testName") exists as a function, struct or class in the
#    repository's Swift sources.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
readme="$root/docs/apps/tiny-worlds/README.md"
problems=0
entry=$(python3 - "$root" <<'PYEOF'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
registration = json.loads((root / "Catalog/registrations.json").read_text())["registrations"]["a12.tiny-worlds"]
entry = next(e for e in json.loads((root / "Catalog/experiences.json").read_text())["experiences"]
             if e["id"] == "a12.tiny-worlds")
print("registration: " + json.dumps(registration, ensure_ascii=False))
print("catalog: " + json.dumps(entry, ensure_ascii=False))
for capability in registration["capabilities"]:
    print("capability\t" + capability)
PYEOF
) || { echo "PROBLEM: the a12.tiny-worlds catalog entry could not be read"; echo "FAIL: claims scan"; exit 1; }
words='accurate|accuracy|precise|precision|scientific|realistic|real-world|geographic|fps|frames per second|battery|[0-9]+([.,][0-9]+)? ?ms'
hits=$(printf '%s\n' "$entry" | grep -v '^capability' | grep -niwE "$words")
if [ -n "$hits" ]; then
    echo "PROBLEM: refused claim in the catalog entry: $hits"
    problems=$((problems + 1))
fi
hits=$(grep -n '' "$readme" | grep -viF 'non-goals:' | grep -iwE "$words")
if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: refused claim in README.md: $line"; done
    problems=$((problems + 1))
fi
table=$(sed -n '/^## Capabilities and their proof/,/^## /p' "$readme" | grep -E '^\| ')
capabilities=$(printf '%s\n' "$entry" | grep '^capability' | cut -f2)
OLDIFS=$IFS
IFS='
'
for capability in $capabilities; do
    if ! printf '%s\n' "$table" | grep -qF "| $capability |"; then
        echo "PROBLEM: capability '$capability' has no row in the README's proof table"
        problems=$((problems + 1))
    fi
done
IFS=$OLDIFS
tests=$(printf '%s\n' "$table" | grep -oE '[A-Za-z0-9]+\.swift[ `]+[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/.*\.swift[ `]+//')
count=0
for name in $tests; do
    count=$((count + 1))
    if ! grep -rqE --include='*.swift' "(func|struct|class) $name[ ({:]" "$root/Packages" "$root/Apps" 2>/dev/null; then
        echo "PROBLEM: proving test '$name' named in README.md does not exist"
        problems=$((problems + 1))
    fi
done
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the proof table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found, 0 refused claims"
