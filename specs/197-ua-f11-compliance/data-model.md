# Data Model: UA-F11

All files are JSON, UTF-8, LF, two-space indentation, keys sorted where generated; every file has `"schema": 1`.
Readers refuse a missing, non-integer or higher schema and an unparsable file, naming the path (FR-U11-081).

## 1. Permission vocabulary — `Configs/permission-vocabulary.json`

```json
{"schema": 1, "words": {"photo-library-add": {"key": "NSPhotoLibraryAddUsageDescription",
                        "text": "Saves exported artwork to your photo library when you choose Save Image."}}}
```
- Word: lower-case kebab, 3–40 chars, unique. Key: matches `^NS[A-Za-z]+UsageDescription$`; each key used by one
  word. Text: 20–200 characters; the property list's text for the key must equal it (FR-U11-012).

## 2. Permission declaration — `Catalog/registrations.json` (registration schema 1, unchanged version)

- Optional `permissions`: list of 0–8 distinct vocabulary words. Absent or empty = no permission.
- Validated by `build_catalog.py`; not copied into the runtime catalog (same rule as `manifest`).
- A01: `["photo-library-add"]`.

## 3. Tracking deny list — `Configs/tracking-denylist.json`

```json
{"schema": 1,
 "frameworks": ["AdSupport", "AppTrackingTransparency", "iAd", "AdServices"],
 "symbols": ["ASIdentifierManager", "advertisingIdentifier", "ATTrackingManager", "requestTrackingAuthorization",
             "trackingAuthorizationStatus"],
 "libraries": {"advertising": ["GoogleMobileAds", "..."], "analytics": ["FirebaseAnalytics", "..."],
               "attribution": ["AppsFlyerLib", "AdjustSdk", "BranchSDK", "..."], "crash-reporting": ["Sentry", "..."]},
 "allowances": [{"text": "...", "file_pattern": "...", "reason": "..."}]}
```
- Texts are case-sensitive literals, 3–80 chars; library names are distinctive module identifiers of at least 6
  characters, matched as whole identifiers (not inside a longer word), so common words never match. All four kinds are present
  with at least three names each. The same library names also fail as imports in sources (`check_compliance.py`).
  Framework names are matched in linked-library lists only; symbol and library names are byte-scanned in every file. An allowance needs a non-empty reason and matches one text in one
  file pattern; an unused allowance fails (no stale exemptions).

## 4. Known game titles — `Configs/known-game-titles.json`

`{"schema": 1, "titles": ["Tetris", "..."]}`; comparison is case-insensitive on whole normalized names.

## 5. Distinctiveness matrix — `docs/legal/distinctiveness-matrix.json` (generated)

```json
{"schema": 1, "catalog_sha256": "<64 hex>", "threshold": 0.5, "measure": "jaccard-player-action-words",
 "experiences": {"A01": {"core_abstraction": "...", "player_action": "...", "win_rule": "open-ended"}, "...": {}},
 "close_pairs": [["R02-G01", "R02-G10"], ["R02-G02", "R02-G03"], ["R02-G09", "R02-G14"],
                 ["R02-G08", "R02-G24"], ["R02-G17", "R02-G18"], ["R02-G13", "R02-G12"]],
 "rows": [["R02-G01", "R02-G10", 0.0, "distinct"], "..."],
 "summary": {"pairs": 4950, "shared": 0, "max_score": 0.375}}
```
- Rows: the six close pairs first (in this order), then all other unordered pairs sorted by score descending, then
  by code. Score rounded to 4 decimals. Verdict `distinct` or `shares-mechanic`; reason for the latter: `triple`,
  `action`, `score`.
- `catalog_sha256`: SHA-256 of the catalog file bytes; a mismatch makes `--check` fail as stale.
- Normalized triple per schema (clarification 2). Normalized words (clarification 3).

## 6. Metadata inputs — `docs/release/metadata-inputs.json` (generated)

```json
{"schema": 1, "ledger_sha256": "<64 hex>",
 "experiences": [{"id": "a01.generative-art-studio", "code": "A01", "name": "...", "tier": "free",
                  "category": "...", "permissions": ["photo-library-add"]}],
 "privacy_answers": {"data_collected": "none", "tracking": "no",
                     "proof": {"executable_sha256": "...", "privacy_report": "...", "tracking_report": "..."}}}
```
- `experiences`: launch experiences whose `X-<code>` gate is `pass`, in queue order. `privacy_answers` is the string
  `"unproven"` unless both reports pass and carry the same executable digest.

## 7. Check report (every new tool `--json`; privacy manifest too)

```json
{"schema": 1, "check": "no-tracking", "meta": {"revision": "<sha>", "clean": true, "configuration": "Release",
 "executable_sha256": "<64 hex>|null"}, "findings": [{"file": "...", "kind": "...", "text": "..."}], "verdict": "PASS"}
```

## State transitions

Distinctiveness verdict per pair: `distinct` ↔ `shares-mechanic` only through a catalog change (a redesign); a
`shares-mechanic` row never leads to removal. Privacy answers: `unproven` → proven only from passing reports of one
executable digest; any later failing report makes the next generation `unproven`.
