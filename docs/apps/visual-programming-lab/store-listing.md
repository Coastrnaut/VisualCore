# Visual Programming Lab — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Visual Programming Lab is
an experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature
171 (A23-P06), FR-A23-605 and FR-A23-606.

Every sentence below describes something that exists in the controls (`VisualProgrammingLab/Experience/LabControls.swift`),
the canvas overlay (`CanvasOverlay.swift`), the library view (`LabLibraryView.swift`), the presenter
(`LabPresenter.swift`) or the adapter (`Experience/Adapter/LabCore.swift`), and is exercised by the tests named in the
traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`
([release.json](release.json) allows no word through `copyCheck.allow`, because Visual Programming Lab hands nothing to
another app) and by the experience's own word scan of T-A23-607 (`specs/171-vpl-p06-release/scan-claims-release.sh`,
the refused words of the spec's Clarifications Q2). The store text names no performance figure, no timing and no value
from a device, and makes no claim beyond what the code holds.

## Text

**Visual Programming Lab** — compose moving pictures from a small graph of nodes, inside VisualCore.
There is no code to type, only nodes and wires.

Seven kinds of node: Time, Constant, Noise, Gradient, Mix, Blur and Output. Each has typed inputs and outputs for
numbers, colours, pictures and time.

Drag a wire from an output to an input on the canvas, pinch to zoom and drag to pan. Every connection can also be made
without dragging, in the list form: pick the source of each input from a list.

A wire that does not fit is refused, and a short sentence says why: a colour into a number, an input that is already
fed, or a loop, named node by node. The status line says whether the graph is ready, has no output, or which input is
empty, and the nodes with a problem are marked.

The preview draws the graph once it is ready, and keeps the canvas drawing when it is not. The Preview switch hides it.

A graph holds at most 32 nodes and 64 connections, and the preview uses at most six textures; a graph past these limits
is refused with its sentence before anything is drawn.

Open one of three example graphs made in code: Clouds, Soft gradient or Mixed clouds.

Save your graphs by name in the library, then open, rename or remove them. Opening a graph over unsaved changes asks
first. Graphs stay on your device; nothing is sent.

Nodes, ports and connections have spoken labels for VoiceOver, and the library's buttons stack at large text sizes.
Visual Programming Lab works offline and needs no permission.

## Traceability

| Claim | Proving test |
|---|---|
| Seven kinds of node: Time, Constant, Noise, Gradient, Mix, Blur and Output, with typed inputs and outputs for numbers, colours, pictures and time | `LibraryTests.swift valueTypesAndKinds`; `LibraryTests.swift kindMatchesTable`; `LibraryTests.swift portsAreWellFormed`; `EditMessagesTests.swift everyKindHasItsTitle`; `TypeCheckTests.swift exactlyTheFourMatchingPairsConnect` |
| There is no code to type: only the known node kinds compile | `CompilerTests.swift theStarterGraphCompilesIntoNoiseAndOutputWithOneSlot`; `CompilerTests.swift everyInvalidFixtureCompilesIntoNoPassWithTheCheckersStatus`; `LabCoreTests.swift theSixControlsAreDeclaredWithTheirRanges`; `TouchTests.swift thePresenterDeclaresItsCapAndActions` |
| Drag a wire on the canvas, pinch to zoom and drag to pan | `TouchTests.swift theJourneyGraphByTouchEqualsTheJourneyByActions`; `TouchTests.swift zoomAndPanNeverChangeTheGraph`; `TouchTests.swift starterPortTargetsAreAtLeast44Points`; `CanvasViewTests.swift pinchClampsAtHalfAndTwo`; `CanvasViewTests.swift panFollowsTheFinger`; `CanvasLayoutTests.swift hitOrderPortThenTopmostNodeThenEmpty` |
| Every connection can also be made without dragging, in the list form | `TouchTests.swift theListFormSendsTheSameConnections`; `LabCoreTests.swift theJourneyGraphIsBuiltByActions`; `VPLCanvasUITests` (the list form builds a Mix graph to "Ready") |
| A wire that does not fit is refused with a short sentence: a colour into a number, an input already fed, or a loop named node by node | `TypeCheckTests.swift colourIntoScalarNamesBothTypes`; `EditorTests.swift aFedInputIsRefused`; `EditorTests.swift aLoopIsRefusedNamingItsConnections`; `CycleTests.swift aLoopOfThreeIsNamedInLoopOrder`; `EditMessagesTests.swift aMismatchNamesBothTypes`; `TouchTests.swift aTypeMismatchByTouchIsRefusedWithItsSentence`; `LabCoreTests.swift everyRefusalFixtureKeepsTheDigestAndShowsItsSentence`; `VPLCanvasUITests` (a mismatched choice shows its sentence) |
| The status line says ready, no output, or which input is empty; the nodes with a problem are marked | `EditMessagesTests.swift everyCheckResultHasItsStatus`; `EditMessagesTests.swift theStatusNamesTheEmptyInputsNode`; `OutputTests.swift anOutputWithNothingConnectedIsDisconnected`; `DiagnosticsTests.swift everyFixtureMarksExactlyTheNodesTheCheckerNames`; `DiagnosticsDisplayTests.swift theMirrorHoldsTheCheckersMarksAfterEachEdit` |
| The preview draws the ready graph and the canvas keeps drawing when it is not; the Preview switch hides it | `PassCountTests.swift theJourneyGraphRunsSixPasses`; `OperatorPixelTests.swift mixMatchesItsReference`; `ProbeTests.swift theOpeningFrameIsNotBlankAndDarkWhereItsProbeLooks`; `PreviewStateTests.swift everyInvalidGraphShowsItsMessageAndDrawsNoPass`; `PreviewStateTests.swift aFailingOperatorShowsItsFailureAndTheCanvasKeepsDrawing`; `PreviewStateTests.swift theHiddenPreviewDrawsNoPassAndKeepsTheDigest` |
| At most 32 nodes and 64 connections, at most six textures; past these limits a graph is refused with its sentence before anything is drawn | `EditorTests.swift addIsRefusedAtThirtyTwoNodes`; `EditorTests.swift aConnectionPastSixtyFourIsRefused`; `TypeCheckTests.swift theLimitsAreCheckedFirstAtAndPastEachBound`; `SlotTests.swift aGraphNeedingSevenSlotsIsRefusedWithTheSentence`; `BudgetTests.swift aGraphOnePastTheLimitIsRefusedBeforeAnyAllocation`; `HostCountTests.swift checkingEveryFixtureInsideTheHostCreatesNoGraphicsResource` |
| Three example graphs made in code: Clouds, Soft gradient or Mixed clouds | `ExampleTests.swift everyExamplePassesTheCheckerAndCompilesWithinTheBudget`; `ExampleTests.swift eachExampleOpensAndDrawsANonFlatInset` |
| Graphs saved by name in the library: open, rename or remove; opening over unsaved changes asks first; graphs stay on your device | `LibraryTests.swift saveOpenRenameAndRemoveRoundTrip`; `LibraryTests.swift aSavedGraphOpensInANewShellWithNoSelection`; `LibraryTests.swift openingOverUnsavedWorkAsksFirstAndDecliningChangesNothing`; `LibraryRefusalTests.swift theCountAndNameCapsRefuseAtOnePastAndChangeNothing`; `LibraryRefusalTests.swift unreadableFilesAreListedRefusedAndKept`; `LibraryRefusalTests.swift aNewerIndexMakesTheLibraryReadOnly`; `MigrationTests.swift anOldFileMigratesAndOpens`; `StoredSampleTests.swift theSampleListsOpensAndStaysUnchanged`; `VPLRecoveryUITests` (a saved graph survives a relaunch) |
| Spoken labels for nodes, ports and connections; the library's buttons stack at large text sizes | `EditMessagesTests.swift nodesAreLabelledByTitleAndIdentity`; `EditMessagesTests.swift portsAreLabelledWithDirectionTypeAndOptional`; `EditMessagesTests.swift connectionsAreLabelledFromSourceToTarget`; `TouchTests.swift thePresenterDeclaresItsCapAndActions`; `LibraryTests.swift withoutStorageTheLibraryIsUnavailableAndTheExamplesStillOpen` |
| Works offline, opens on the state of the last session; nothing is sent | `LabCoreTests.swift theSnapshotRoundTripsAndDamagedSnapshotsAreRefused`; `LabManifestTests.swift theSaveRestoreStateSurvivesARestore`; `LabCoreTests.swift theStarterGraphIsNoiseIntoOutput`; `VPLReleaseUITests` (a fresh start is "Ready" with two nodes and an empty library) |

The source scan of the experience (`scan-sources`, T-A23-603) proves that no network, tracking, sensor, recording,
sound input, photo-library, `UIPasteboard`, `ShareLink`, idle-timer or brightness use is in
`Packages/ExperiencesCreative/VisualProgrammingLab` (`.autonomy/checks/A23-P06.scan-sources.json`). Visual Programming
Lab asks for no permission (`"permissions": []` in `Catalog/registrations.json`). See
[privacy-and-credits.md](privacy-and-credits.md) and [licenses.md](licenses.md). No speed, timing, heat, memory or
device claim is made. The interface tests of chunk `e3` (`VPLCanvasUITests`, `VPLRecoveryUITests`, `VPLReleaseUITests`;
T-A23-608) prove the journeys through the app's controls on the iOS 27 phone simulator; they are simulator results, not
device measurements. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
