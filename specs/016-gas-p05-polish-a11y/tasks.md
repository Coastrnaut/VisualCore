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

- [X] T-A01-506 [US2] Add `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CanvasDescription.swift` — Verified 2026-11-11: Core CanvasDescription.swift: '<Family>, <preset> preset, <palette> palette, seed <n>, <playing/paused>.'; the preset matches only if seed, palette and the schema-resolved values equal the document (else 'custom preset'); unknown palette gives 'custom palette'. CanvasDescriptionTests 3/3 (default preset for all 4 families, a palette change → custom preset + new palette + paused, unknown palette). SceneScreen uses it as the gas.scene.canvas accessibility label (refreshed with the document and the 0.25 s play-state refresh), with the family description as the hint. run-check A01-P05/t506-core-tests-a2 30/30 (a1 failed: preset values are partial; fixed by resolving with schema defaults); t506-app-build BUILD SUCCEEDED. UI behavior verified by T-A01-507
  (`text` = "<Family>, <preset> preset, <palette> palette, seed <n>, <playing/paused>."; a preset that no longer
  matches gives "custom"; an unnamed palette gives "custom palette") with host tests in `CanvasDescriptionTests.swift`.
  Use it for the `gas.scene.canvas` accessibility label in `SceneScreen.swift`, refreshed on edits and on play state
  (FR-A01-503).
- [X] T-A01-507 [US2] Add `Apps/GenerativeArtStudio/Tests/UI/AccessibilityAuditUITests.swift`: — Verified 2026-11-11: Tests/UI/AccessibilityAuditUITests.swift: performAccessibilityAudit on gallery, settings, library, scene, controls and export at the default size (all types except Dynamic Type/clipping, which are predictions there) and at UICTContentSizeCategoryAccessibilityXXXL (all types); documented exclusions logged per spec Clarifications (canvas artwork contrast, navigation-bar chrome, findings without an element); canvas label follows a palette change and pause ('Neon palette', 'custom preset', 'paused.'). App fixes for every finding on our views: accessible accent tint (AppColors #0040DD/#409CFF), primary text instead of secondary, headerProminence(.increased) section headers, opaque controls-sheet background, bottom scroll-edge effect hidden on the controls and export forms, a 44-pt play/pause target, plain 'System' picker values with the device state in a full-contrast row, plain export rows, scene title on one line with the Large Content Viewer. scripts/check_test_enumeration.py (+ test_scripts case) guards against silent short enumerations. run-check A01-P05/t507-ui-all-ios27 13/13; t507-ui-all-ios26 ran only 9/13 (the 4 new tests silently not enumerated; guard FAIL; not counted) → t507-ui-all-ios26-a2 13/13; t507-enumeration-guard (ios26-a2) and -ios27 PASS 13/13; documented API PASS (FR-A01-504, SC-A01-503)
  `performAccessibilityAudit` on gallery, scene, controls, export, library and settings, at the default size and with
  `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`. Only contrast issues on
  `gas.scene.canvas` may be ignored, and each is logged. The canvas label changes after a palette change. Fix every
  issue found in the app views. Run on iOS 27.2 and 26.5 (FR-A01-504, SC-A01-503).

## Phase 4: US3 — Scenes survive backgrounding and context loss (P1)

- [X] T-A01-508 [US3] Add `Apps/GenerativeArtStudio/Tests/Unit/LifecycleRegressionTests.swift`. For 4 families, — Verified 2026-11-11: Tests/Unit/LifecycleRegressionTests.swift (the manual's Phase 05 regression fixture), 5 tests: background/foreground for 4 families → no frame while backgrounded, same time, image mean 0.0 max 0; recreateContext for 4 families → new generation, leaked 0, stale delta over 5 frames 0, image mean 0.0 max 0, live counts one for one; 20 background cycles + 3 recreations with live counts unchanged and 0 leaked; export after recovery identical to export before (max 0) for 4 families; the Reduce Flashing limiter graph is rebuilt after recreation with no error or leak. run-check A01-P05/t508-unit-ios27 + ios26 36/36 unit tests each, confirmed by t508-enumeration-ios27/ios26 PASS 36/36 (FR-A01-505, SC-A01-504)
  paused at t:
  - posting `didEnterBackground` then `willEnterForeground`: `renderOneFrame` is false while backgrounded and true
    after; the image matches (mean ≤ 1/255);
  - `recreateContext()`: the image matches, the stale delta over the next 5 frames is 0, and leaked is 0;
  - 20 background cycles plus 3 recreations: live counts unchanged;
  - an export after recovery equals an export before;
  - with Reduce Flashing on: recreation keeps the limiter working.

  Run on both runtimes (FR-A01-505, SC-A01-504).

## Phase 5: Polish

- [X] T-A01-509 Update `docs/apps/generative-art-studio/visualcore-contract.json` (G-UI closed at A01-P05; M10 — Verified 2026-11-11: visualcore-contract.json gate A01-P05: M10 available (SceneClock, RenderHost.pause, RenderSurface + AccessibilityPreferences, SystemAccessibilityObserver, EffectScene.bypassEffects; SceneModel.apply example), G-UI closed A01-P05 with the actual tests named; all 10 rows available and all 7 gaps closed; rendered; check PASS 10 rows, 47 citations. regression-baseline.md Phase 05 section: reference 7/7 after the VisualCore change, app suite counts with the enumeration guard, lifecycle fixture results, audit scope, and the remaining documented exclusions (navigation-bar Done buttons and the inline title only). run-check A01-P05/t509-release-fast 8/8 (docs, app-contracts, compliance incl. offline, dependencies incl. no ProjectM, public-api, licenses, script-tests incl. the enumeration guard test, host-visualcore); t509-documented-api-app PASS; full suites with the current app code: t507-ui-all-ios27 13/13 + t507-ui-all-ios26-a2 13/13, t508-unit-ios27/ios26 36/36 (each enumeration-guarded) (FR-A01-507, FR-A01-508, SC-A01-505)
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

## Phase 6: Convergence

- [X] T-A01-510 Move the reusable accessibility-settings pieces into VisualCore per Constitution II (Maximize reuse) and FR-A01-506 (partial): — Verified 2026-11-11: VisualCoreSimulation: AccessibilityPreferences.keys(prefix:), load(from:keyPrefix:), save(to:keyPrefix:) (<prefix>.reduceMotion/.reduceFlashing raw values; unknown/absent → System) + host test storageRoundTripAndFallback. VisualCoreUI/AccessibilitySettingsSection.swift: AccessibilitySettingsSection(preferences:system:identifierPrefix:) (System/On/Off pickers with accessibility values, full-contrast explanation row with the device setting, prominent header) and AccessibleColors (accent #0040DD/#409CFF, WCAG contrastRatio) + AccessibilitySettingsSectionTests 3/3 (explanation text, hosts in a Form and writes the binding, accent ≥ 4.5:1 on white, grouped and black). API baseline 875 (0 undocumented after documenting body); READMEs, package map, getting-started, known-limitations. run-check A01-P05/t510-fast-a2 5/5 (t510-fast failed on the undocumented body, fixed); t510-rendering-ios27/ios26 TEST SUCCEEDED; reference regression t510-reference-a 3/3 + b 4/4 = 7/7
  - `AccessibilityPreferences.load(from: UserDefaults-like store, keyPrefix:)` / `save(to:keyPrefix:)` with the keys
    `<prefix>.reduceMotion` / `<prefix>.reduceFlashing` (raw `AccessibilityChoice`; unknown or absent → System), in
    `Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift` with host tests;
  - VisualCoreUI `AccessibilitySettingsSection` (System/On/Off pickers bound to `AccessibilityPreferences`,
    identifier prefix parameter, full-contrast explanation row showing the device setting from
    `SystemAccessibilityObserver`) and `AccessibleColors.accent` (#0040DD light / #409CFF dark), in
    `Packages/VisualCoreRendering/Sources/VisualCoreUI/`, with simulator tests;
  - docs, API baseline, R1–R5 and the ProjectM regression (7 steps).
- [X] T-A01-511 Adopt them in `Apps/GenerativeArtStudio/App/{SettingsView,SceneScreen,GenerativeArtStudioApp}.swift`, keeping the identifiers `gas.settings.*` and the keys `gas.a11y.*`; delete `AppColors.swift` and `AccessibilityStorage`; rerun the full unit and UI suites (including the accessibility audit) on iOS 27.2 and 26.5, enumeration-guarded, per Constitution II (partial) — Verified 2026-11-11: App adopts VisualCore: SettingsView = AccessibilitySettingsSection(identifierPrefix gas.settings) + About; keys from AccessibilityPreferences.keys(prefix: gas.a11y) (AppAccessibility enum keeps only the prefix); tint AccessibleColors.accent; AppColors.swift and AccessibilityStorage deleted. ControlsUITests scrub assertion made layout-independent (the 44-pt play button narrowed the slider: 71.0 s at 0.5): mid-timeline 42-78 s and label equals the slider's spoken value. docs/testing/simulator-test-lessons.md (silent short enumeration, stale package framework in app DerivedData, layout-independent UI assertions) linked from docs/index.md. run-check A01-P05/t511-app-all-ios27 failed on that assertion; t511-app-all-ios27-a2 49/49 (36 unit + 13 UI) and t511-app-all-ios26 49/49, both enumeration-guarded (…-guard PASS); t511-controls-ios26 2/2 with the changed test; documented API and compliance PASS (Constitution II)
