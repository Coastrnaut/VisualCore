# Data model: A07-P04

- **JourneyPreset** (format 1): id (UUID), name (cleaned, ≤ 60, empty → "Untitled"), saved (Date), world, mappings
  ([WorldMapping] × 3), speedTarget (0.5…7, 0.5 steps), easing, calmMotion, isBuiltIn (not stored). Built-ins:
  "Deep tunnel" …7B1, "Rolling hills" …7B2, "Night stars" …7B3 (clarification 2), saved 0.
- **JourneyPresetStore**: entries (built-ins, then user presets by name ignoring case, ties by id), unreadable, newer,
  lastMessage; save(name:from:), rename(_:to:), delete(_:), preset(_:), reload().
- **Action** `preset.apply` [16 values] (data model D2 in research); refused with `a07.invalid-preset` if any value is
  out of range.
- **DemoResponseTrace**: frames [(primary, light)], maxPrimary, rest.
