# Shader Studio — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Shader Studio is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 164
(A22-P06), FR-A22-605 and FR-A22-606.

Every sentence below describes something that exists in the controls (`ShaderStudio/Experience/StudioControls.swift`),
the editor (`StudioEditor.swift`), the inspector (`StudioInspector.swift`), the library view
(`StudioLibraryView.swift`), the presenter (`StudioPresenter.swift`) or the adapter
(`Experience/Adapter/StudioCore.swift`), and is exercised by the tests named in the traceability table. The text is
checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` ([release.json](release.json) allows
no word through `copyCheck.allow`, because Shader Studio hands nothing to another app) and by the experience's own word
scan of T-A22-607 (`specs/164-ss-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications
Q2). The store text names no performance figure and no value from a device, and makes no claim beyond what the code
holds.

## Text

**Shader Studio** — a small studio for GLSL ES 3.00 fragment shaders, inside VisualCore.

Start from one of four templates written in code: Gradient, Noise flow, Rings or Texture mix.

Edit the source in a monospaced editor with line numbers and syntax colours. Run compiles your shader; on a hardware
keyboard, Command-R runs it and Command-' moves to the next error.

When a run fails, each error is listed on the line you wrote, the line is marked, and a short sentence says what to
change. Tap an error to move the cursor to its line. The preview keeps drawing the last shader that worked.

Move the float uniforms of your shader in the inspector, each within its range, and reset them to their defaults. Give
Texture mix one of three textures made in code: Checker, Ramp or Noise.

Save your work as named projects in the library, then open, rename or remove them. Projects stay on your device.

A source past the limits is refused before it is compiled, with the reason. A shader whose frames keep taking too long
is stopped, and Reset preview brings back the last shader that ran well.

Your shaders run on the device's graphics processor. GPU code is not a sandbox: Shader Studio stops a slow preview, but
makes no promise about what a shader may do to the device while it runs.

The uniforms, the textures, the marked lines and the advice have spoken labels for VoiceOver, and the editor follows
your text size. Shader Studio works offline
and needs no permission.

## Traceability

| Claim | Proving test |
|---|---|
| GLSL ES 3.00 fragment shaders; four templates written in code: Gradient, Noise flow, Rings or Texture mix | `TemplateCompileTests.swift thereAreFourTemplatesInOrderWithLicences`; `TemplateCompileTests.swift textureMixDeclaresTwoInputsAndABlend`; `StudioCoreTests.swift everyTemplateDrawsWithTheStatusCompiled`; `ProbeTests.swift theOpeningTemplateIsRedWhereItsProbeLooks`; `SSReleaseUITests` (a fresh start opens Gradient, compiled) |
| A monospaced editor with line numbers and syntax colours | `TokenizerTests.swift everyKindIsClassified`; `TokenizerTests.swift tokensRebuildEveryLineExactly`; `EditorDocumentTests.swift linesAreNumberedFromOneWithTokens`; `EditorModelTests.swift thePaletteMapsEveryKindAndEmphasisIsNotColour`; `EditorModelTests.swift gutterRowsFollowTheWrappedLines` |
| Run compiles your shader; an edit alone compiles nothing | `RunQueueTests.swift threeRunsBeforeAFrameGiveOneCompileOfTheNewestSource`; `RunQueueTests.swift setSourceAloneNeverCompiles`; `EditorModelTests.swift anEditUpdatesTheEditorAndNeverCompiles` |
| Command-R runs and Command-' moves to the next error | `EditorModelTests.swift nextErrorSkipsOutsideEntriesAndWraps`; `SSReleaseUITests` testCommandRRunsTheShader (Command-R on the hardware keyboard runs a broken shader, the status turns to Failed) |
| Each error on the line you wrote, the line marked; tap an error to move the cursor to its line | `LineMappingCompileTests.swift fixturesHaveTheErrorOnTheirLine`; `LineMappingCompileTests.swift errorInAnIncludeIsOutsideTheSource`; `AssemblyTests.swift expansionMapsThePersonsLinesBack`; `EditorModelTests.swift aBrokenRunMarksExactlyItsLineAndAFixClearsIt`; `EditorModelTests.swift choosingADiagnosticGivesItsLineStart`; `SSEditorUITests` (a broken line is marked and listed; the fix clears both) |
| A short sentence says what to change | `GuidanceTests.swift everyCodeHasADistinctSentence`; `GuidanceCompileTests.swift undeclaredIdentifierNamesTheIdentifier`; `GuidanceDisplayTests.swift aBrokenCompileCarriesItsGuidanceAndAFixClearsIt`; `GuidanceDisplayTests.swift everyStatusHasItsGuidance`; `SSLibraryUITests` (a version line is refused with guidance) |
| The preview keeps drawing the last shader that worked | `LastGoodPreviewTests.swift aBrokenCompileKeepsTheGoodPictureAndNamesTheAuthoredLine`; `LastGoodPreviewTests.swift aLinkErrorKeepsTheGoodPicture`; `LastGoodPreviewTests.swift aFirstRunThatFailsKeepsTheFirstTemplate`; `RebuildTests.swift theLastGoodShaderIsDrawnAgainAfterAContextLossAndAResize` |
| Float uniforms in the inspector, each within its range, reset to their defaults | `InspectorTests.swift theRowsMatchTheLiveProject`; `InspectorTests.swift valuesStopAtTheEndsNonFiniteIsRefusedAndResetRestores`; `UniformPreviewTests.swift twoValuesGiveDifferentPicturesWithoutACompile`; `SSEditorUITests` (the slider changes and Reset restores it) |
| Three textures made in code: Checker, Ramp or Noise | `TextureRecipeTests.swift recipesAreInChoiceOrderWithTitles`; `TextureRecipeTests.swift checksumsArePinned`; `TextureInputTests.swift theThreeChoicesGiveThreeDifferentPictures`; `TextureInputTests.swift eachInputHasItsSizeAndChecksumAndIsBoundToItsUnit` |
| Named projects in the library: save, open, rename or remove; they stay on your device | `LibraryTests.swift saveOpenRenameAndRemoveRoundTrip`; `LibraryTests.swift everyCapRefusesWithItsMessageAndChangesNothing`; `LibraryTests.swift unreadableFilesAreListedKeptAndOnlyRemovedOnRequest`; `LibraryTests.swift aNewerIndexMakesTheLibraryReadOnly`; `SSLibraryUITests` (a saved project opens with its source); `SSRecoveryUITests` (a saved project survives a relaunch) |
| A source past the limits is refused before it is compiled, with the reason | `ValidatorTests.swift sourceBytesAtAndPastLimit`; `ValidatorTests.swift linesAtAndPastLimit`; `ValidatorTests.swift uniformsAtAndPastLimit`; `ValidatorTests.swift textureInputsAtAndPastLimit`; `OversizedProjectTests.swift aSourceOneBytePastTheLimitIsRefused`; `LastGoodPreviewTests.swift aRefusedSourceCompilesNothing` |
| A shader whose frames keep taking too long is stopped; Reset preview brings back the last shader that ran well | `FrameWatchdogTests.swift eightSlowIntervalsStop`; `FrameWatchdogTests.swift sevenSlowThenNormalDoNotStop`; `WatchdogTests.swift eightSlowIntervalsStopThePreviewAndTheFrameIsFlat`; `WatchdogTests.swift normalIntervalsNeverStopIt`; `WatchdogTests.swift resetBringsBackTheFallbackWithNoCompile` |
| GPU code is not a sandbox; Shader Studio stops a slow preview and promises nothing more | `WatchdogTests.swift eightSlowIntervalsStopThePreviewAndTheFrameIsFlat`; `RecoveryTests.swift tenRebuildsWhileStopped`; the experience's word scan (T-A22-607) requires this sentence and refuses every safety word |
| Spoken labels for the uniforms, the textures, the marked lines and the advice; the editor follows your text size | `InspectorTests.swift theRowsMatchTheLiveProject`; `TextureInputTests.swift theThreeChoicesGiveThreeDifferentPictures`; `EditorModelTests.swift aBrokenRunMarksExactlyItsLineAndAFixClearsIt`; `GuidanceDisplayTests.swift aVersionLineIsRefusedWithItsSentenceAndLine`; `EditorModelTests.swift theLayoutStacksAtCompactWidthsAndAccessibilitySizes` |
| Works offline and opens on the state of the last session | `StudioCoreTests.swift theSnapshotRoundTripsAndDamageIsRefused`; `StudioManifestTests.swift theSaveRestoreStateSurvivesARestore`; `ShapeTests.swift aSnapshotWithoutShapeReadsTheTemplatesCounts`; `SSReleaseUITests` (a fresh start is compiled with one uniform and an empty library) |

The source scan of the experience (`scan-sources`, T-A22-603) proves that no network, tracking, sensor, recording,
sound input, photo-library, `UIPasteboard`, `ShareLink`, idle-timer or brightness use is in
`Packages/ExperiencesCreative/ShaderStudio` (`.autonomy/checks/A22-P06.scan-sources.json`). Shader Studio asks for no
permission (`"permissions": []` in `Catalog/registrations.json`). See [privacy-and-credits.md](privacy-and-credits.md)
and [licenses.md](licenses.md). No speed, timing, heat, memory or device claim is made. The interface tests of chunk
`d3` (`SSEditorUITests`, `SSLibraryUITests`, `SSRecoveryUITests`, `SSReleaseUITests`; T-A22-608) prove the journeys
through the app's controls on the iOS 27 phone simulator; they are simulator results, not device measurements. Device
measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
