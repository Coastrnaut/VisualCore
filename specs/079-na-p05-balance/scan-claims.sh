#!/bin/sh
# scan-claims.sh — feature 079 (A10-P05) T-A10-504 (FR-A10-521; SC-A10-504; clarification 5). Three checks:
# 1. The Neon Arcade catalog entry (its registration in Catalog/registrations.json and its entry in
#    Catalog/experiences.json) and docs/apps/neon-arcade/README.md contain none of the benefit-claim words (skill,
#    reflex, cognitive, health, brain, "improve your"; whole words, case-insensitive).
# 2. Every capability of the registration has a row in the README's "Capabilities and their proof" table.
# 3. Every proving test named in that table ("File.swift testName") exists as a function, struct or class in the
#    repository's Swift sources.
# Prints PASS or one PROBLEM line per finding and FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
readme="$root/docs/apps/neon-arcade/README.md"
problems=0
entry=$(python3 - "$root" <<'EOF'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
registration = json.loads((root / "Catalog/registrations.json").read_text())["registrations"]["a10.neon-arcade"]
entry = next(e for e in json.loads((root / "Catalog/experiences.json").read_text())["experiences"]
             if e["id"] == "a10.neon-arcade")
print("registration: " + json.dumps(registration, ensure_ascii=False))
print("catalog: " + json.dumps(entry, ensure_ascii=False))
for capability in registration["capabilities"]:
    print("capability\t" + capability)
EOF
) || { echo "PROBLEM: the a10.neon-arcade catalog entry could not be read"; echo "FAIL: claims scan"; exit 1; }
words='skills?|reflex(es)?|cognitive|health(y)?|brain|improves? your'
hits=$(printf '%s\n' "$entry" | grep -v '^capability' | grep -niwE "$words")
if [ -n "$hits" ]; then
    echo "PROBLEM: benefit claim in the catalog entry: $hits"
    problems=$((problems + 1))
fi
hits=$(grep -niwE "$words" "$readme")
if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | while IFS= read -r line; do echo "PROBLEM: benefit claim in README.md: $line"; done
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
echo "PASS: claims scan, $count proving tests found, 0 benefit claims"
