# Data model: R02-F26

- `ShellPreferences.haptics: Bool?` — absent or true = on; JSON key `haptics`; schema 1 unchanged.
- `GestureDeclaration { id: String, kind: tap|doubleTap|longPress|drag|pinch|rotate, priority: Int, pointers: 1...2 }`.
- `GestureOutcome { gesture: String, phase: began|changed|ended|cancelled|recognized, values: [Double] }`.
- `Announcement { text: String, kind: rejection|outcome|level|state, time: Double }`.
- `HapticEvent { kind: selection|success|warning|error|impactLight|impactMedium|impactHeavy, time: Double }`.
- `StateSign { id: String, colorHex: String, sign: String }`.
