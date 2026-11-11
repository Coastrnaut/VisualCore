---

description: "Task list for feature 016 — Generative Art Studio Phase 05 polish, accessibility and regression (ledger gate A01-P05)"
---

# Tasks: Generative Art Studio — Phase 05 Polish, accessibility and regression

**Input**: `/specs/016-gas-p05-polish-a11y/`. **Tests** are required:
- host preference and description tests;
- VisualCoreRendering simulator tests;
- hosted app accessibility and lifecycle tests;
- UI settings and audit tests on both runtimes;
- the reference regression.

IDs are `T-A01-5##`, with one commit and push per task (`scripts/tick_task.py`).

**Checkpoints**:
- after Phase 1: the API baseline, rules R1–R5 and the reference regression;
- after each phase: `validate_docs.py`.

## Phase 1: Foundational — VisualCore accessibility settings (US4; blocks US1)

- [X] T-A01-501 [US4] Add `Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift`: — Verified 2026-11-11: VisualCoreSimulation/AccessibilityPreferences.swift: AccessibilityChoice (system/on/off, titles, init(storedValue:) and lenient Codable: unknown → system), SystemAccessibility, EffectiveAccessibility (playbackRate = SceneClock.reducedMotionFactor 0.5 or 1), AccessibilityPreferences.resolve. AccessibilityPreferencesTests 4/4: 12 resolution cases, Off overrides system On, playback rate, stored values + Codable incl. unknown raw value; run-check A01-P05/t501-visualcore-host swift test exit 0
  - `AccessibilityChoice` (`system`, `on` and `off`; String raw values; `title` "System", "On" or "Off"; the rule
    "unknown raw → `system`" through `init(storedValue:)`);
  - `SystemAccessibility`;
  - `AccessibilityPreferences` (Codable, defaults `.system`) with `resolve(_:)`;
  - `EffectiveAccessibility`, where `playbackRate` = reduceMotion ? `SceneClock.reducedMotionFactor` : 1.

  Add `Tests/VisualCoreSimulationTests/AccessibilityPreferencesTests.swift`: the 12 resolution cases (2 system states
  × 3 choices × 2 settings), the playback rate, unknown and nil stored values, and a Codable round trip.
- [X] T-A01-502 [US4] Add `Packages/VisualCoreRendering/Sources/VisualCoreUI/SystemAccessibilityObserver.swift` — Verified 2026-11-11: VisualCoreUI/SystemAccessibilityObserver.swift (@MainActor @Observable; replaceable source; systemValues() from UIAccessibility.isReduceMotionEnabled + MADimFlashingLightsEnabled(); refresh on reduceMotionStatusDidChangeNotification and kMADimFlashingLightsChangedNotification via NotificationCenter.default; tokens removed in isolated deinit); VisualCoreUI → VisualCoreSimulation dependency; EffectScene.bypassEffects (content draws into context.framebuffer directly, renderer untouched). Tests 6/6: observer injected source/refresh, both notifications refresh, public-API values; bypass identical to direct content with no renderer built; limiter keeps per-frame luma change ≤ 0.3/60 + 1/255 on black/white alternation, bypass shows unlimited content, same renderer instance after bypass with no jump; 0 leaked and 0 live after destroy. run-check A01-P05/t502-rendering-ios27 + ios26 TEST SUCCEEDED
  (`@MainActor @Observable`; the source can be replaced; `systemValues()` from `UIAccessibility.isReduceMotionEnabled`
  and `MADimFlashingLightsEnabled()`; refresh on `UIAccessibility.reduceMotionStatusDidChangeNotification` and
  `kMADimFlashingLightsChangedNotification` (a local-center notification, observed through `NotificationCenter.default`
  as `Notification.Name(kMADimFlashingLightsChangedNotification as String)`; analyze U1); observers removed on deinit). Add the VisualCoreUI → VisualCoreSimulation
  dependency in `Packages/VisualCoreRendering/Package.swift`. Add `EffectScene.bypassEffects` in
  `Sources/VisualCoreEffects/EffectScene.swift`: when true, the content renders directly into the host framebuffer,
  the graph and limiter are skipped and the renderer is untouched.

  Tests:
  - `Tests/VisualCoreUITests/SystemAccessibilityObserverTests.swift`: the injected source, `refresh()`, and a
    refresh on a posted reduce-motion notification;
  - `Tests/VisualCoreEffectsTests/EffectSceneBypassTests.swift`: bypass output identical to the content rendered
    directly; the limiter renderer instance is kept across bypass on/off; 0 leaks after destroy.

  Run on iOS 27.2 and 26.5.
- [X] T-A01-503 [US4] Update the docs: — Verified 2026-11-11: API baseline 865 declarations (+26: AccessibilityChoice/SystemAccessibility/EffectiveAccessibility/AccessibilityPreferences, SystemAccessibilityObserver, EffectScene.bypassEffects), 0 undocumented; VisualCore README 'Accessibility preferences'; VisualCoreRendering README 'Accessibility settings and effect bypass'; package-map rows (Simulation, Effects, UI incl. the new UI → Simulation dependency); support-matrix row (A01-P05); known-limitations built note; getting-started module table. run-check A01-P05/t503-fast 5/5 (docs, dependencies R1-R5, public-api, compliance, host-visualcore); t503-reference-a 3/3 + t503-reference-b 4/4 = reference regression 7/7 (FR-A01-506, SC-A01-505)
  - API baseline;
  - VisualCore README "Accessibility preferences";
  - VisualCoreRendering README (observer, bypass);
  - package-map rows;
  - `docs/release/{support-matrix,known-limitations}.md` and `docs/getting-started.md`.

  Run R1–R5, the host tests and the reference regression (7 steps) (FR-A01-506, SC-A01-505).

## Phase 2: US1 — Motion and flashing follow my settings (P1) 🎯

- [X] T-A01-504 [US1] Wire the app: — Verified 2026-11-11: App: GenerativeArtStudioApp provides one SystemAccessibilityObserver; SettingsView (pickers gas.settings.reduceMotion/reduceFlashing with System (On/Off) option titles and accessibility values, @AppStorage gas.a11y.*, footer 'Off overrides the system setting', About 'Works offline. No account, no tracking.', Done); Gallery Settings button gas.settings.open; SceneModel host scene = EffectScene(clocked, one copy pass) with bypass by default, apply(_:) sets clock.reducedMotion, timeScale, reduceFlashing and bypassEffects = !reduceFlashing, called on appear and onChange of the effective settings; ExportRunner forces bypass during the render and restores it; project.yml adds VisualCoreEffects + VisualCoreEffectsGraph. Two export tests now compare live counts with the pre-export counts (the wrapper owns one scene target). A stale VisualCoreSimulation framework in the gitignored app DerivedData was cleared. run-check A01-P05/t504-app-all-ios27 + ios26 37/37 passed, 0 failed (Phase 01–04 regression); documented API PASS; compliance PASS. Behavior verified by T-A01-505
  - `GenerativeArtStudioApp.swift` provides one `SystemAccessibilityObserver` in the environment;
  - new `App/SettingsView.swift`: pickers `gas.settings.reduceMotion` and `gas.settings.reduceFlashing` with
    `@AppStorage("gas.a11y.reduceMotion")` and `("gas.a11y.reduceFlashing")`; footer `gas.settings.footer` "Off
    overrides the system setting."; About `gas.settings.about` "Works offline. No account, no tracking."; Done
    `gas.settings.done`;
  - `GalleryView.swift`: button `gas.settings.open`;
  - `SceneScreen.swift`: the host scene is `EffectScene(content: clocked, graph: one copy pass)`;
    `SceneModel.apply(_ effective:)` sets `clock.reducedMotion`, `effect.reduceFlashing` and
    `effect.bypassEffects = !reduceFlashing`; it is called on appear and on change of the observer or the stored
    choices;
  - `ExportSheet.swift`: `ExportRunner` sets `bypassEffects = true` during the render and restores it;
  - `project.yml`: add the VisualCoreEffects product to the app.

  (FR-A01-501, FR-A01-502)
- [X] T-A01-505 [US1] Add `Apps/GenerativeArtStudio/Tests/Unit/AccessibilityApplyTests.swift`: — Verified 2026-11-11: Tests/Unit/AccessibilityApplyTests.swift (SceneModel gained a sceneOverride test seam; the override gets the real clock + EffectScene wrapping): rate 1/60 → 0.5/60 on the next frame after apply and back (SC-A01-501); black/white alternation unlimited max Δ 1.0, with system Dim Flashing Lights + choice System the per-frame mean-luma change is 0.0039 ≤ bound 0.3/60 + 1/255 = 0.0089 after the start frame (the limiter seeds on the toggle frame, so that frame is the content's own transition; spec edge case refined to say so); an export meanwhile is unlimited (pixel 0 or 255), the limiter renderer instance is unchanged, no jump after it, and Off overrides system On (SC-A01-502); a system change while backgrounded applies on the first frame after foreground (analyze C1). Tests/UI/SettingsUITests.swift: System defaults, footer and About, set Reduce Motion On, relaunch keeps On, reset (launch-argument defaults were dropped because the argument domain masks @AppStorage writes). run-check A01-P05/t505-apply-settings-ios27 + ios26 4/4 passed, 0 failed
  - `apply` switches the clock rate (0.5×/1×) and the limiter within one frame;
  - a black↔white alternating test scene wrapped like the app's gives a per-frame mean-luma change ≤ 0.3 × (1/60) +
    1/255 with Reduce Flashing, and about 1 without;
  - an export while limiting equals the unlimited content (max difference 0), and the limiter renderer instance is
    unchanged afterwards.
  - a system change delivered while the host is suspended (backgrounded) takes effect on the first frame after
    foreground (spec edge case; analyze C1).

  Add `Tests/UI/SettingsUITests.swift`: defaults "System"; set Reduce Motion to "On"; relaunch and the value is kept;
  the footer text. Run both on iOS 27.2 and 26.5 (SC-A01-501, SC-A01-502).

## Phase 3: US2 — Canvas description, VoiceOver and large text (P1)

- [ ] T-A01-506 [US2] Add `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CanvasDescription.swift`
  (`text` = "<Family>, <preset> preset, <palette> palette, seed <n>, <playing/paused>."; a preset that no longer
  matches gives "custom"; an unnamed palette gives "custom palette") with host tests in `CanvasDescriptionTests.swift`.
  Use it for the `gas.scene.canvas` accessibility label in `SceneScreen.swift`, refreshed on edits and on play state
  (FR-A01-503).
- [ ] T-A01-507 [US2] Add `Apps/GenerativeArtStudio/Tests/UI/AccessibilityAuditUITests.swift`:
  `performAccessibilityAudit` on gallery, scene, controls, export, library and settings, at the default size and with
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`. Only contrast issues on
  `gas.scene.canvas` may be ignored, and each is logged. The canvas label changes after a palette change. Fix every
  issue found in the app views. Run on iOS 27.2 and 26.5 (FR-A01-504, SC-A01-503).

## Phase 4: US3 — Scenes survive backgrounding and context loss (P1)

- [ ] T-A01-508 [US3] Add `Apps/GenerativeArtStudio/Tests/Unit/LifecycleRegressionTests.swift`. For 4 families,
  paused at t:
  - posting `didEnterBackground` then `willEnterForeground`: `renderOneFrame` is false while backgrounded and true
    after; the image matches (mean ≤ 1/255);
  - `recreateContext()`: the image matches, the stale delta over the next 5 frames is 0, and leaked is 0;
  - 20 background cycles plus 3 recreations: live counts unchanged;
  - an export after recovery equals an export before;
  - with Reduce Flashing on: recreation keeps the limiter working.

  Run on both runtimes (FR-A01-505, SC-A01-504).

## Phase 5: Polish

- [ ] T-A01-509 Update `docs/apps/generative-art-studio/visualcore-contract.json` (G-UI closed at A01-P05; M10
  available with AccessibilityPreferences, SystemAccessibilityObserver and EffectScene evidence) and render it.
  Update `docs/apps/generative-art-studio/regression-baseline.md` with the audit exclusions and the lifecycle
  fixture. Run `check_app_contract`, the documented API, the release-check fast steps and the full app suites on both
  runtimes (FR-A01-507, FR-A01-508, SC-A01-505).

## Dependencies

T-A01-501 → T-A01-502 → T-A01-503 → T-A01-504 → T-A01-505. T-A01-506 → T-A01-507 (needs T-A01-504's settings
screen). T-A01-508 needs T-A01-504 (the EffectScene wrapper). T-A01-509 runs last.

## Implementation strategy

VisualCore first (Principle II), then the settings wiring, the canvas and audit, the lifecycle fixture, and the
contract.

## Analyze remediation (2026-11-11)

Applied autonomously (CLAUDE.md §2): C1 → T-A01-505 background-change case; U1 → T-A01-502 notification delivery. 0
critical issues.
