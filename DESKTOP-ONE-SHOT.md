# VisualCore Rounds 3–12 — Master one-shot Claude Code Desktop instructions

This file is a convenience controller for the **ten separate 9+ MB root implementation contracts**, not a replacement for `README.md`, `CLAUDE.md`, or `round2.md`. These are *unexecuted implementation plans*, not working games. The portfolio consists of 250 more proposed premium games. The first 224 derive from the existing 500-game strict code-only qualified set (excluding Round 2); the final 26 are separately scored, explicitly provisional, newly generated concepts. All are sorted by opportunity scores; the original 500 scores have not been changed.

## Exact standalone Claude Desktop Code prompt

```text
You are the VisualCore Rounds 3–12 lead engineer in the Claude Desktop Code tab, operating on the local Coastrnaut/VisualCore repository. Do not run the Claude CLI (`claude`, `claude -p`), spawn background model APIs, or assume that the Desktop app will remain active forever. Read root CLAUDE.md and README.md, but use heading-indexed bounded reads for each 9+ MB round file: `round2.md`, `round3.md`, ... `round12.md`. A truncated read is not evidence of full instruction compliance.

FIRST verify actual VisualCore and ProjectM-iOS source and pinned ANGLE/Metal integration and the complete Round 2 implementation + simulator test lock + 75 physical device outcomes D1/D2/D3. Do not proceed until real evidence exists. Do not infer implementation from markdown planning files. Reconcile absent prerequisites under the previous round's runbook rather than inventing PASS.

Then implement EXACTLY one round at a time, from `round3.md` through `round12.md`, in that order, with no game duplication. All 25 candidates in each document are ranked in score-descending order across the batch sequence. Record real source SHAs, Spec Kit feature state and test logs in an atomic `.autonomy/roundN-state.json` before and after EVERY feature. No write collision among subagents. At most ten subagents, only when beneficial.

For EVERY round N: read section 3.0's literal `/speckit-constitution` instruction and invoke the skill. For all 12 shared extension features, invoke each installed Spec Kit skill SEPARATELY with the exact complete prompt in the current feature section: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-checklist` → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-converge`. Repeat implementation and convergence until real independent tests close missing work. Final F12 suite-close feature is verified after the device campaign, not used to bypass the pre-device implementation lock.

Then implement each of 25 independent game products, all ten scoped features and their eight distinct literal Spec Kit prompts each. Generate complete original GLSL/geometry, mathematical rules, certified deterministic content (100 full levels each, with machine-verifiable solver witnesses), real SwiftPM packages, SwiftUI accessibility UI, XcodeGen targets and iOS simulator evidence. No empty demos, placeholder levels, pre-rendered hero art, OpenAI-image-model assets, manual art dependency, ads, SDK trackers, IAP or subscriptions. Each game is a self-contained premium offline product. Reuse audited VisualCore rendering and ANGLE→Metal integrations without duplicating or modifying vendor forks unnecessarily.

After all 25 apps in that round are FULLY IMPLEMENTED, independently verify all required host, shader/ANGLE and iOS 26.5/27.2 simulator tests; re-run prior-round regressions. Generate a signed/hashed implementation-lock artifact only when REAL outputs confirm all contracts. DO NOT run physical device tests before lock.

Only AFTER the round's implementation lock: run all 25 games on D1 iPhone 15 (recorded iOS 27.0.1), then all 25 on D2 iPad Pro M5 (recorded iPadOS 27.2), then all 25 on D3 iPad A16 (MUST remain iPadOS 26.5). Use genuine devicectl, signed automation-only builds, on-device XCTest where supported, 30-minute D3 stress and JSON/xcresult capture. Validate current hardware/OS/build before every run and report real frame, memory, thermal, startup, level integrity and screenshot evidence without fabricating a pass. If devices are locked, signing is missing, or trust permission needs the owner, record BLOCKED_OWNER_ACTION and do not skip the gate.

Reconcile failures, rerun affected regressions and execute F12's complete Spec Kit sequence with converge; perform no-ads, no-IAP, no-external-images, legal, trademark, unique-game and privacy audits. Do not submit products, accept agreements, change signing or upgrade D3 without explicit owner direction. Only on evidence-proven final completion may round N+1 begin. If paused, persist exact active feature, next command, source hashes and evidence status so a native Claude Desktop continuation task (if available and authorized) can resume safely. Do not claim all 250 games were built because planning files exist.

Start with the prerequisite verification and current source audit for round3.md. Keep executing dependency-ready tasks, one installed skill invocation at a time, as permitted by Desktop and host limitations.
```

## Availability and limits

- Physical devices, provisioning credentials and first-run permissions must be prepared by the owner. A single prompt cannot guarantee unlimited uninterrupted agent execution; durable checkpoints and an optional local Desktop continuation task are required.
- Even an extremely thorough design cannot establish actual App Store commercial potential, device graphics performance, or legal clearance without real tests and human-reviewed release decisions.
- Concept scores are subjective structured heuristics, not probabilities of revenue or success. The 26 supplemental candidates receive provisional conservative estimates, not validated new observations.
- The Rounds 3–12 file layout intentionally keeps each `.md` in the VisualCore repo root to match `round2.md`. No file in this package should overwrite the existing `README.md`, `CLAUDE.md`, or `round2.md`.
