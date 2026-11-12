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

`vc.tile.<id>`, `vc.section.<category id>`, `vc.route.catalog|experience|settings|about`, `vc.nav.settings`,
`vc.nav.about`, `vc.nav.done`, `vc.search`, `vc.search.clear`, `vc.empty`, `vc.nomatch`, `vc.error`, `vc.welcome`,
`vc.welcome.start`, `vc.settings.reduceMotion`, `vc.settings.reduceFlashing`, `vc.settings.quality`,
`vc.settings.reset.all`, `vc.settings.reset.<id>`, `vc.settings.reset.confirm`, `vc.settings.reset.cancel`,
`vc.settings.privacy`, `vc.about.acknowledgements`, `vc.experience.back`, `vc.premium.notice`,
`vc.premium.dismiss`, `vc.diagnostics` (debug builds), and `experience.<id>.<control>` inside an experience (the framework's
`ExperienceID.accessibilityPrefix`).

## 7. As built (recorded after T-U04-011)

- Settings and about are reached through two list rows above the tiles, not through toolbar items: a navigation
  bar clips text at the largest accessibility sizes and its tinted text does not reach the audit's contrast.
- The search field is a text field in the first list row; it wraps at the largest text sizes.
- The welcome replaces the navigation instead of covering it; the reset confirmation and the premium notice are
  sheets with their own buttons.
- An available premium entry is shown as a tile even without a registration and opens the premium notice; it is
  listed in the diagnostics as a registry mismatch until the purchase feature registers it. A free entry is shown
  only when it is available and registered.
- Section headings and reset rows use the label colour; the app's tint is the framework's contrast-checked
  accent. The destructive meaning of a reset is carried by its symbol and its confirmation, not by a red text.
- `-vcSkipWelcome` marks the welcome as seen. `-openExperience <id>` opens its experience directly, also on a
  first start: the welcome is hidden for that launch and stays unseen, so the next start without the argument
  shows it (convergence, T-U04-034).
- Further debug-only arguments (convergence): `-vcDamagedCatalog` (catalog data that cannot be read),
  `-vcSeedData` (a data folder for the first two free fixture experiences) and `-vcFailingExperience` (every
  fixture experience fails in its setup).
- The way back from the experience, settings and about routes (`vc.experience.back`, `vc.nav.done`) is a row of
  the content, not a bar button: a navigation bar keeps its buttons 36 points high, below the 44 points of
  FR-U04-035 (found by the touch-target test of T-U04-040).
- The registration's factory receives an `ExperienceLaunch` with the stored reduce-motion and reduce-flashing
  choices (US5, acceptance scenario 1). Settings closes an open experience, so a changed choice reaches an
  experience at its next open.
- The search field is replaced by a new one when typed text is cut to 100 characters, and keeps the focus: a field
  that is being typed in does not take a shorter text back from its binding.
- What stays in a release build of the debug support is inert data only: the launch arguments the model was
  created with and the list of arguments that were not understood (always empty there, because nothing reads the
  arguments). The handling itself (`DebugLaunch`, `DebugExperience`, `hideWelcomeForThisLaunch`) does not exist.
- The app test runner takes the narrowest available phone simulator of the runtime (an iPhone 13 mini was
  created for both runtimes); a tablet run is recorded in three chunks, each under ten minutes.
- The seed of an opened experience is derived from its id (a stable value); UA-F05 will supply stored seeds.
