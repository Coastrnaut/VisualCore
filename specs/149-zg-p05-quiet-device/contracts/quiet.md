# Contract: Digital Zen Garden quiet defaults, interface and campaign (A20-P05)

- **Defaults:** a fresh experience has sound, drift and haptics off; the switches persist across a reopen; turning them
  on leaves the digest unchanged.
- **Reduced motion:** frames at two frame times are identical with the drift off, and with the drift on under Reduce
  Motion; they differ with the drift on otherwise.
- **Sound and haptics:** the player is disabled while sound is off; commits, placements and removals request a tone
  only when sound is on; haptics only when on.
- **Interface (`b3`):** `ZGGardenUITests` (pattern, undo, stone place, remove, undo) and `ZGLibraryUITests` (save
  "Evening", open it); each under 60 s.
- **Campaign:** 8 rows with device, procedure, threshold and "pending device campaign"; no number.
