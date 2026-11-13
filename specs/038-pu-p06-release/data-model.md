# Data Model: A04-P06

- **Library file** (`scene-<uuid>.json`, sorted keys): `format` Int (absent = 1; written as 1), `id` UUID (equals the
  file name), `saved` Date (seconds since 2001-01-01), `document` SceneDocument v2 (v1 migrated). States: readable,
  newer (`format > 1` or document version > 2: counted, kept, never opened), unreadable (counted, kept).
- **Experience release config** (`docs/apps/particle-universe/release.json`, schema 1): `experience` id,
  `requiredDocs` [paths], `checklist` path.
- **Release checklist row**: Item | Area | Status (`verified` / `pending-campaign-ii` / `owner-action`) | Evidence or
  steps (non-empty).
- **Copy denylist** (`Configs/copy-claims-denylist.json`, schema 1): `patterns` [{`id`, `regex`, `reason`}], `words`
  [{`word`, `reason`}].
