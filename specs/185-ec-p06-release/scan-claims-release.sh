#!/bin/sh
# scan-claims-release.sh — feature 185 (A25-P06) T-A25-607 (contracts/release.md; clarification Q2 on the claims
# words). Modelled on specs/178-gbl-p06-release/scan-claims-release.sh. Three checks:
# 1. None of the refused words appear: video, animated, animation, layers, layer, masks, mask, RAW, HDR, AI,
#    machine learning, neural, professional, pro-grade, lossless, unlimited, real-time, instant, fps, cloud, sync,
#    account, upload, Photoshop, Lightroom, Instagram and filter-pack. Words are matched whole and case-insensitively
#    in (a) the store text, whole file; (b) the summary and capabilities of the "a25.effects-composer" entry of
#    Catalog/registrations.json; (c) the interface Swift of Effects Composer (ECControls, ComposerPresenter,
#    PreviewRenderer, StillExport, ImageImport, LookLibrary, EffectsComposerExperience and Experience/Adapter/*.swift).
#    Unlike the A24 script, which scanned its interface Swift whole, only the Swift string literals (the text between
#    double quotes, multi-line literals included, interpolated code and "//" comments left out) are scanned here:
#    these files draw a picture through a chain of passes, and code identifiers and comments may truthfully say
#    "layer" or "mask" (a CALayer, a bit mask, a colour mask) without being a claim the user ever reads. Every text a
#    user reads in the interface is a string literal.
# 2. The store text contains the phrase "Nothing is sent".
# 3. Every proving test named in the store text's claim table (the backticked names in its "Proving test" column)
#    exists: "File.swift name" needs that file and a func or @Test display name "name"; a bare name ending in Tests
#    needs a class or struct of that name; any other bare name needs a func or @Test display name. Tests are searched
#    in Packages/ExperiencesCreative/EffectsComposer/*Tests/ and Apps/VisualCore/Tests/UI/EffectsComposer/.
# STORE=path overrides the store text (for testing this script). Prints PASS or one PROBLEM line per finding and
# FAIL; exit 1 on any finding.
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
store="${STORE:-$root/docs/apps/effects-composer/store-listing.md}"
reg="$root/Catalog/registrations.json"
me="$root/Packages/ExperiencesCreative/EffectsComposer"
ui="$root/Apps/VisualCore/Tests/UI/EffectsComposer"
x="$me/Experience"
swift="$x/ECControls.swift $x/ComposerPresenter.swift $x/PreviewRenderer.swift $x/StillExport.swift $x/ImageImport.swift $x/LookLibrary.swift $x/EffectsComposerExperience.swift"
for file in "$x"/Adapter/*.swift; do swift="$swift $file"; done
problems=0
for file in "$store" "$reg" $swift; do
    if [ ! -f "$file" ]; then echo "PROBLEM: ${file#$root/} is missing"; echo "FAIL: claims scan"; exit 1; fi
done
tests=""
for d in "$me"/*Tests "$ui"; do [ -d "$d" ] && tests="$tests $d"; done
words='video|animated|animation|layers|layer|masks|mask|raw|hdr|ai|machine learning|neural|professional|pro-grade|lossless|unlimited|real-time|instant|fps|cloud|sync|account|upload|photoshop|lightroom|instagram|filter-pack'
# Prints "line:text" for every line, lower-cased (portable case-insensitive matching), for the whole store text.
whole() { awk '{ print NR ":" tolower($0) }' "$1"; }
# Prints "line:literals" for every line of a Swift file holding string-literal text: only the characters inside
# "..." and """...""" literals, without escapes, interpolated code \( ... ) or "//" comments.
literals() {
    awk '
    BEGIN { state = 0 }   # 0 code, 1 single-line literal, 2 multi-line literal, 3 block comment
    {
        s = $0; n = length(s); out = ""; i = 1
        if (state == 1) state = 0
        while (i <= n) {
            c = substr(s, i, 1)
            if (state == 3) { if (substr(s, i, 2) == "*/") { state = 0; i += 2 } else i++; continue }
            if (state == 0) {
                if (substr(s, i, 2) == "//") break
                if (substr(s, i, 2) == "/*") { state = 3; i += 2; continue }
                if (substr(s, i, 3) == "\"\"\"") { state = 2; i += 3; out = out " "; continue }
                if (c == "\"") { state = 1; i++; out = out " "; continue }
                i++; continue
            }
            if (c == "\\") {
                if (substr(s, i + 1, 1) == "(") {
                    depth = 1; i += 2
                    while (i <= n && depth > 0) { d = substr(s, i, 1); if (d == "(") depth++; else if (d == ")") depth--; i++ }
                    out = out " "; continue
                }
                i += 2; continue
            }
            if (state == 2 && substr(s, i, 3) == "\"\"\"") { state = 0; i += 3; out = out " "; continue }
            if (state == 1 && c == "\"") { state = 0; i++; out = out " "; continue }
            out = out c; i++
        }
        if (state == 2) out = out " "
        if (out ~ /[^ ]/) print NR ":" tolower(out)
    }' "$1"
}
report() { # file, lines-with-prefix
    hits=$(printf '%s\n' "$2" | grep -iwE "$words" | cut -d: -f1)
    if [ -n "$hits" ]; then
        for n in $hits; do echo "PROBLEM: refused claim in ${1#$root/}:$n: $(sed -n "${n}p" "$1")"; done
        problems=$((problems + 1))
    fi
}
report "$store" "$(whole "$store")"
for file in $swift; do report "$file" "$(literals "$file")"; done
entry=$(python3 - "$reg" <<'EOF'
import json, sys
def find(node):
    if isinstance(node, dict):
        if "a25.effects-composer" in node and isinstance(node["a25.effects-composer"], dict):
            return node["a25.effects-composer"]
        for v in node.values():
            r = find(v)
            if r is not None:
                return r
    return None
e = find(json.load(open(sys.argv[1])))
if e is None:
    sys.exit(2)
print("summary: " + str(e.get("summary", "")))
for c in e.get("capabilities", []):
    print("capability: " + str(c))
EOF
)
if [ -z "$entry" ]; then
    echo "PROBLEM: the a25.effects-composer entry of Catalog/registrations.json was not found"
    problems=$((problems + 1))
else
    rhits=$(printf '%s\n' "$entry" | grep -iwE "$words")
    if [ -n "$rhits" ]; then
        printf '%s\n' "$rhits" | while IFS= read -r line; do
            echo "PROBLEM: refused claim in Catalog/registrations.json a25.effects-composer $line"
        done
        problems=$((problems + 1))
    fi
fi
if ! grep -q 'Nothing is sent' "$store"; then
    echo "PROBLEM: the phrase 'Nothing is sent' is missing from ${store#$root/}"
    problems=$((problems + 1))
fi
# The backticked names of the "Proving test" column (found from the claim table's header row), one per line.
names=$(awk -F'|' '
    /^\|/ {
        if (col == 0) { for (i = 2; i < NF; i++) if (tolower($i) ~ /proving test/) col = i; next }
        if ($0 ~ /^\|[- :|]+$/) next
        cell = $col
        while (match(cell, /`[^`]+`/)) { print substr(cell, RSTART + 1, RLENGTH - 2); cell = substr(cell, RSTART + RLENGTH) }
        next
    }
    { col = 0 }' "$store")
exists_test() { # name: a func or an @Test display name
    grep -rqE "func $1[ (<]" $tests 2>/dev/null || grep -rqF "@Test(\"$1\"" $tests 2>/dev/null
}
count=0
newline='
'
IFS_SAVED=$IFS
IFS=$newline
for name in $names; do
    IFS=$IFS_SAVED
    count=$((count + 1))
    case "$name" in
        *.swift\ *)
            file=${name%%.swift *}.swift; test=${name#*.swift }
            if [ -z "$(find $tests -name "$file" 2>/dev/null)" ]; then
                echo "PROBLEM: test file '$file' named in store-listing.md does not exist"
                problems=$((problems + 1))
            fi
            if ! exists_test "$test"; then
                echo "PROBLEM: proving test '$test' ($file) named in store-listing.md does not exist"
                problems=$((problems + 1))
            fi ;;
        *Tests)
            if ! grep -rqE "(class|struct) $name[ :{]" $tests 2>/dev/null; then
                echo "PROBLEM: test suite '$name' named in store-listing.md does not exist"
                problems=$((problems + 1))
            fi ;;
        *)
            if ! exists_test "$name"; then
                echo "PROBLEM: proving test '$name' named in store-listing.md does not exist"
                problems=$((problems + 1))
            fi ;;
    esac
    IFS=$newline
done
IFS=$IFS_SAVED
if [ "$count" -eq 0 ]; then echo "PROBLEM: no proving test found in the claim table"; problems=$((problems + 1)); fi
if [ "$problems" -gt 0 ]; then echo "FAIL: claims scan, $problems problems"; exit 1; fi
echo "PASS: claims scan, $count proving tests found"
