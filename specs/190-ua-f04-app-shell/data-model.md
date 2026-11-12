# Data model: UA-F04

## 1. Shell preferences (schema 1)

JSON under the key `vc.shell.preferences`:

| Key | Type | Rule |
|---|---|---|
| `schema` | integer | 1; a higher number or unreadable data gives defaults and the note `preferences.newer` or `preferences.unreadable` |
| `welcomeSeen` | boolean | default false |
| `lastRoute` | text | `catalog`, `settings`, `about` or `experience:<id>`; default `catalog` |
| `searchText` | text | at most 100 characters; default empty |
| `qualityOverride` | integer or absent | absent = automatic; 0…7 |
| `reduceMotion`, `reduceFlashing` | text | `system`, `on` or `off`; default `system` |

At most 64 KiB; larger data is treated as unreadable.

## 2. Launcher model

Input: manifest, category list, registered ids, search text. Output: a state.

| State | When |
|---|---|
| `error(code)` | the catalog could not be loaded |
| `empty` | no experience is both available and registered |
| `noMatch` | experiences exist but the search finds none |
| `sections` | one section per category that has tiles, in the order of the category list; tiles in catalog order, or in the order of the search result when a search text is given |

Tile: id, title, summary, tier text (`Free` or `Premium`), premium flag, two colours, seed, identifier
`vc.tile.<id>`.

## 3. Startup decision

| Input | Result |
|---|---|
| `welcomeSeen == false` | show the welcome; its action opens the first available, registered, free experience, or the catalog when there is none |
| last route is an experience that is available and registered | that experience |
| last route is an experience that is not | the catalog |
| otherwise | the stored route |

## 4. Reset plan

`experience(id)` → remove the folder of that id's storage namespace. `all` → remove every experience folder and the
preferences value; the app is then as after a first start. An open experience is closed first.

## 5. App diagnostics

Catalog state (loaded with counts, or the error code), registry mismatches (ids), preference note, unknown test
arguments, last reset (what was removed). Readable in debug builds through the identifier `vc.diagnostics`.

## 6. Identifiers

`vc.tile.<id>`, `vc.route.catalog|experience|settings|about`, `vc.nav.settings`, `vc.nav.about`, `vc.search`, `vc.empty`, `vc.nomatch`,
`vc.error`, `vc.welcome`, `vc.welcome.start`, `vc.settings.quality`, `vc.settings.reset.all`,
`vc.settings.reset.<id>`, `vc.settings.privacy`, `vc.about.acknowledgements`, `vc.experience.back`,
`vc.premium.notice`.
