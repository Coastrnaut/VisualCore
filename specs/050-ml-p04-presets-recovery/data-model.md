# Data model: A06-P04

- **AudioSessionEvent** (VisualCore): `interruptionBegan`, `interruptionEnded(shouldResume: Bool)`, `routeLost`,
  `mediaServicesReset`.
- **AudioSourceState** (VisualCore): `idle`, `running`, `interrupted` (new), `failed(String)`.
- **MusicPreset** (Core): `id` (UUID), `name` (cleaned: trimmed, ≤ 60 characters, empty → "Untitled"), `scene`
  (MusicLabScene), `choices` ([MappingChoice], count = scene's parameter count), `saved` (Date), `isBuiltIn` (Bool, not
  coded). File format 1 (see spec clarification 4). Validation: format ≤ 1, id matches file name, scene known, choices
  valid and of the right count.
- **Preset library** (experience): `entries` (user presets sorted by name, then built-ins first in the list),
  `unreadable` (count), `newer` (count), `lastMessage` (String?).
- **Status** (experience mirror): `status` text and `recovery` (none, resume, useDemo).
