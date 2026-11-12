# Contract: Sandbox UI for A04-P03

Phase 01–02 identifiers stay. New:

| Identifier | Element | Text / behavior |
|---|---|---|
| `pu.sandbox.emitter` | menu picker | "Emitter 1" … "Emitter N" (selects the emitter the family picker and overrides edit) |
| `pu.sandbox.emitters` | text | "Emitters: N of 8" (+ " — waiting for removed emitters to fade" when slots are busy) |
| `pu.sandbox.addEmitter` | button "Add emitter" | adds the selected family; disabled at 8 busy slots |
| `pu.sandbox.removeEmitter` | button "Remove emitter" | removes the selected one; shown only with two or more emitters (a disabled button failed the contrast audit) |
| `pu.sandbox.size` | slider 1…48 | value "N points" |
| `pu.sandbox.lifetime` | slider 0.2…8 | value "N.N seconds" |
| `pu.sandbox.gradient` | menu | "Family colors", Sunset, Ocean, Forest, Neon, Monochrome, Ember |
| `pu.sandbox.trails` | toggle "Trails" | disabled in the CPU preview |
| `pu.sandbox.trailStrength` | slider 0…0.98 | value "N percent" (s × 100, rounded) |
| `pu.sandbox.blend` | segmented "Normal" / "Additive" | |
| `pu.sandbox.trailNote` | text | "Brightness limited (Reduce Flashing)" and/or "Trails need the GPU renderer" when applicable |

DEBUG launch argument: `-uitestReduceFlashing YES`.
