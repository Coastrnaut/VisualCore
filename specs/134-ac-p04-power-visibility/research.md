# Research: A18-P04 (feature 134)

- **D1 Frame cap (clarification Q1):**
  - **Decision:** a static per-presenter value, read when the session builds its host.
  - **Rationale:** it is additive, needs no change to `RenderHost`, and `FramePacing` keeps the floor and the heat and
    Low Power Mode rules.
  - **Alternative:** a dynamic cap per frame. Not needed, because 30 is the floor anyway.
- **D2 Night (Q2):** a dim and warm tint in the shader; warm amber text (#FFB27A) checked against all 48 dimmed colours.
  The schedule is evaluated on the local minute of the day.
  - **Alternative:** writing the screen brightness. Refused (constitution 2.14.0, A18).
- **D3 Drift (Q3):** a two-frequency sine (periods 600 s and 840 s), 8 points, at most about 5 points per minute, zero
  under reduced motion. The idle dim is 0.6 after 600 s without an action.
  - **Alternative:** Digital Aquarium's `AmbientDimmer`. Not copied, because it belongs to that experience's core.
- **D4 Keep-awake (Q4):** an injectable `IdleTimerPort`, so tests never touch `UIApplication`. A source-scan test pins
  the single file.
- **D5 Schema 3 (Q5):** the defaults fill the new fields, and the schema-1 and schema-2 examples are both registered.
