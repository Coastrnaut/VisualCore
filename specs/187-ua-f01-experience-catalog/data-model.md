# Data Model: UA-F01 — Experience catalog and stable identity

## 1. Experience code and id

| Entity | Form | Rules |
|---|---|---|
| Code | `A<nn>` (nn 01–99) or `R<rr>-G<gg>` (rr 02–99, gg 01–99) | upper case; two digits each; parsed and printed identically |
| Slug | `[a-z0-9]+(-[a-z0-9]+)*` | 1 to 60 characters |
| Id | `<code in lower case>.<slug>` | unique; never changes; never reused |

Derived names (functions of the id or code only):

| Name | Form | Example |
|---|---|---|
| integration gate | `X-<code>` | `X-A05` |
| storage namespace | the id | `a05.infinite-geometry` |
| accessibility prefix | `experience.<id>` | `experience.a05.infinite-geometry` |
| evidence name | the id | `a05.infinite-geometry` |

## 2. Experience descriptor (one entry of `Catalog/experiences.json`)

Exactly these keys; any other key is an error.

| Key | Type | Rules |
|---|---|---|
| `id` | string | valid id; unique |
| `code` | string | valid code; equals the code inside the id; unique |
| `title` | string | 1 to 80 characters |
| `summary` | string | at most 300 characters |
| `kind` | string | `creative` or `game` |
| `tier` | string | `free` or `premium` |
| `category` | string | `create`, `audio`, `play`, `learn`, `ambient`, `tools` or `puzzle`; a game is `puzzle`, a creative experience is not |
| `family` | string | 1 to 60 characters |
| `tags` | list of strings | at most 16, each 1 to 60 characters; contains the family in tag form (lower case, groups of letters and digits joined by hyphens) |
| `order` | whole number | 1 to 9,999; unique |
| `palette` | list of strings | at most 8; each `#RRGGBB` |
| `tile_seed` | whole number | 0 to 4,294,967,295 |
| `capabilities` | list of strings | at most 16, each 1 to 40 characters |
| `quality_tiers` | list of strings | at most 8, each 1 to 40 characters |
| `content` | `null` or object | for a game with a registration: `levels` (whole number 0 to 10,000) and `catalog_sha256` (64 hexadecimal digits) |
| `available` | Boolean | true only when the integration gate is pass |

## 3. Catalog manifest (`Catalog/experiences.json`)

```json
{ "schema": 1, "catalog_sha256": "<64 hexadecimal digits>", "experiences": [ { … }, … ] }
```

Validation, in this order: size at most 1,048,576 bytes → JSON object → `schema` is 1 → exactly the three keys →
at most 400 entries → every entry valid (section 2) → no duplicate id, code or order → entries in ascending order
→ launch allocation: codes `A01`–`A25` and `R02-G01`–`R02-G25` present once and free, `R03-G01`–`R04-G25` present
once and premium → every other entry has a round of 05 to 12 and is premium → when a category list is given,
every category is in it.

## 4. Category list (`Catalog/categories.json`)

```json
{ "schema": 1, "categories": [ { "id": "create", "title": "Create" }, … ] }
```

Exactly seven entries in launcher order: create, audio, play, learn, ambient, tools, puzzle. A title has 1 to 40
characters. Same size cap; unknown keys are errors.

## 5. Registrations (`Catalog/registrations.json`)

```json
{ "schema": 1, "registrations": { "<id>": { "capabilities": [], "quality_tiers": [], "palette": [], "content": null } } }
```

Read by the build tool only. Empty today. A key must be an id of the planning catalog.

## 6. Executed source moves (`Catalog/path-map.json`)

```json
{ "schema": 1, "moves": [ { "from": "<path>", "to": "<path>", "gate": "<gate id>", "commit": "<short hash>" } ] }
```

Empty today; at most 5,000 moves; a path has 1 to 300 characters.

## 7. Golden id list (`Catalog/experience-ids.golden.txt`)

One id per line, in catalog order, LF line endings, 300 lines today. It only grows: the build tool appends ids of
experiences that are new in the planning catalog when asked with `--add-golden`, and refuses when a listed id is
absent from the planning catalog.

## 8. Errors

`ExperienceIDError`: `malformed(text, reason)`.

`CatalogError` (each case comparable):

| Case | When |
|---|---|
| `tooLarge(bytes, limit)` | data over the size cap |
| `unreadable(reason)` | not JSON, or not an object of the expected shape |
| `unsupportedSchema(found, supported)` | another schema version |
| `tooManyEntries(count, limit)` | more than 400 entries, or a list over its limit at the top level |
| `missingField(entry, field)` | a required key is absent |
| `unknownField(entry, field)` | a key the schema does not define |
| `wrongType(entry, field)` | a value of the wrong type |
| `invalidValue(entry, field, reason)` | unknown tier, kind or category, malformed id, empty title, text or list over its limit, code and id that disagree, family missing among the tags |
| `invalidNumber(entry, field, reason)` | not finite, not whole, or out of range |
| `duplicate(field, value)` | a repeated id, code or order |
| `outOfOrder(entry)` | entries not in ascending catalog order |
| `allocation(code, reason)` | the launch allocation rule is broken |

`entry` is the id when it could be read, otherwise the index as text.

## 9. Search

Folded text of a descriptor: title, tags, summary, each folded once at load (research R4). Query: fold, split at
spaces, drop empty words. Rank of an entry: for each word the best field that contains it (title 0, tags 1,
summary 2; no field: the entry does not match); the entry's rank is the largest of these. Result order: rank,
then catalog order. Empty query: all entries in catalog order.

## 10. Registry report

Input: the manifest and a list of registered ids. Output: `missingRegistrations` (available entries without a
registered id), `unexpectedRegistrations` (registered ids whose entry is missing or not available), `duplicates`
(ids registered more than once), each sorted by id; `isMatch` is true when all three are empty.
