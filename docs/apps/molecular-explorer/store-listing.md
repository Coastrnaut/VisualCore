# Molecular Explorer — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Molecular Explorer is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 115
(A15-P06), FR-A15-620 and FR-A15-621 (research D2).

Every sentence below describes something that exists in the controls
(`MolecularExplorer/Experience/MoleculeControls.swift`), the canvas (`MoleculePresenter.swift`) or the model
(`MolecularExplorer/Core`), and is exercised by the tests named in the traceability table. The text is checked by
`scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` (one word is allowed for this experience,
`camera` in `copyCheck.allow` of [release.json](release.json): the experience's 3D view has a virtual camera that the
controls and gestures turn, tilt, zoom and pan; the device camera is never used) and by the experience's own word scan
of T-A15-608 (`specs/115-me-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The
store text names no performance figure and no value from a device, and states no chemical property beyond what is drawn
and listed; the structures are illustrative models from their stated sources.

## Text

**Molecular Explorer** — five small molecules in 3D, atom by atom in element colours, drawn entirely by code, inside
VisualCore.

Choose water, methane, ethanol, benzene or caffeine from the Molecule menu or the Library, or step through them in
order. Each one shows its name, formula, atom and bond counts and its source: a public-domain 3D structure from
PubChem.

Two display modes: Ball and stick draws the atoms joined by their bonds, a double bond as two sticks; Space filling
draws each atom at its van der Waals radius. The legend says that the radii are for display, not measured sizes.

Turn, tilt, zoom and pan the view with a finger or with buttons, and Reset view frames the molecule again.

Tap an atom, or step through the atoms with Next atom and Previous atom, to see its element, its position, its radii
and every bond it has. Labels name the atoms by element symbol and never overlap; show them for all atoms, only for
the selected one, or not at all.

The Recent menu lists the molecules you opened, newest first. The recent list and the label setting are kept on your
device, and a stored file that cannot be read is reported and left as it is.

Import a small XYZ file of your own from Files: up to 64 KB and 500 atoms of the ten elements the explorer knows (H,
C, N, O, F, P, S, Cl, Br and I). Its bonds are inferred from the distances between the atoms and marked as inferred. A
file that cannot be opened is refused with the reason, and nothing changes.

Every element value and every molecule structure carries its source and license, from PubChem and published covalent
radii.

VoiceOver reads every control with its value, describes the canvas with the molecule, the display mode and the
selected atom, and announces a newly selected atom. Every gesture has a button that does the same.

The experience reopens where you left it. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Five small molecules in 3D, atom by atom in element colours, drawn entirely by code | `MoleculeLibraryTests.swift fiveMoleculesLoadInOrderWithTheirCountsAndFormulas`; `MoleculeRenderTests.swift testEveryMoleculeDrawsANonBlankFrame`; `MoleculeRenderTests.swift testTheUnitMeshesTheModelMatricesAndTheColours`; `MoleculeRenderTests.swift testTheExperienceNeverCreatesAGraphicsContextOfItsOwn`; `ElementsTests.swift theTenElementsHaveTheClarifiedValuesInAtomicNumberOrder` |
| Choose a molecule from the Molecule menu or the Library, or step through them in order | `MoleculeStateTests.swift selectingAcceptsOnlyTheFiveMolecules`; `MoleculeStateTests.swift nextAndPreviousStepAndStopAtTheEnds`; `MoleculeLibraryUITests.swift testChoosingALibraryEntrySelectsItAsTheMoleculeMenuDoes`; `MoleculeSessionTests.swift testNextAndPreviousStepThroughTheLibraryAndARefusedStepIsAnswered`; `MoleculeRenderTests.swift testChangingTheMoleculeChangesTheDrawnPixelsTheLinesAndTheDescription` |
| Name, formula, atom and bond counts and the source, a public-domain 3D structure from PubChem | `MoleculeLibraryUITests.swift testEveryLibraryEntrysWords`; `MoleculeLibraryTests.swift everyStructureRecordIsPubChemPublicDomain`; `MoleculeTests.swift theFormulaIsInHillOrder`; `MoleculeCoreTests.swift testTheLinesAndTheCanvasDescriptionFollowClarificationQ5` |
| Ball and stick with a double bond as two sticks; Space filling at the van der Waals radius | `MoleculeSceneTests.swift theModesSetTheRadiiAndTheSticks`; `BondStyleTests.swift caffeineDoubleBondsGiveTwoSticksPerHalf`; `MoleculePanelTests.swift testCaffeinesDoubleBondsChangeTheDrawnPixels`; `MoleculeSceneRenderTests.swift testBothModesDrawEveryMoleculeAndDiffer`; `MoleculeSceneRenderTests.swift testTheModeChangesTheWordsAndKeepsTheMoleculeAndTheCamera` |
| The legend says that the radii are for display, not measured sizes | `MoleculeWordsTests.swift testThePanelShowsBothStatements`; `MoleculeReviewTests.swift theStatementsAndClaimWordsAreFixed`; `MoleculeReviewTests.swift theDocumentListsEveryValueAndBothStatements` |
| Turn, tilt, zoom and pan with a finger or with buttons; Reset view frames the molecule again | `MoleculeCameraTests.swift testEveryCameraStepChangesTheFrameAndKeepsTheCentre`; `MoleculeCameraTests.swift testResetViewFramesTheMoleculeAgain`; `MoleculeGestureTests.swift testADragThroughTheSessionEqualsPressingTurnLeftThreeTimes`; `MoleculeGestureTests.swift testAPinchZoomsInAndOutInSteps`; `MoleculeGestureTests.swift testMovingTwoFingersPansSoTheMoleculeFollows`; `CameraSettingsTests.swift tiltAndZoomRefuseBeyondTheirLimits` |
| Tap an atom or step with Next atom and Previous atom; its element, position, radii and bonds | `MoleculePickingTests.swift testATapOnCaffeinesThirdAtomSelectsItAndATapOnACornerClears`; `MoleculePickingTests.swift testPickingUsesTheDrawnCameraAfterTurnsAndPans`; `AtomPickerTests.swift eachProjectedCentrePicksTheNearestAtomAlongItsLineOfSight`; `MoleculeStateSchema3Tests.swift atomStepsFollowTheirRules`; `MoleculePanelTests.swift testThePanelLinesNameTheAtomAndItsBonds` |
| Labels by element symbol that never overlap, for all atoms, the selected one or none | `LabelLayoutTests.swift placedLabelsNeverOverlap`; `MoleculePanelTests.swift testTheLabelsNeverOverlapAndTheSelectedAtomComesFirstWithItsRing`; `MoleculeLibraryUITests.swift testTheLabelsPickerChangesTheOverlaysLabelCount`; `MoleculeSettingsTests.swift everyModeRoundTripsByteExactly` |
| The Recent menu lists the molecules opened, newest first | `MoleculeLibraryUITests.swift testTheRecentMenuListsNewestFirst`; `RecentMoleculesTests.swift recordingKeepsTheNewestEightUniqueIdsFirst`; `RecentMoleculesTests.swift reRecordingMovesAnIdToTheFront` |
| The recent list and the label setting are kept on the device | `RecentStoreTests.swift testARecordedListLoadsBackInANewStore`; `RecentStoreTests.swift testTheListSurvivesANewSessionOverTheSameStorage`; `SettingsStoreTests.swift testAChangedModeLoadsBackInANewStore`; `SettingsStoreTests.swift testTheSettingsSurviveANewPresenter` |
| A stored file that cannot be read is reported and left as it is | `RecentStoreTests.swift testRefusedFilesStayByteIdenticalWithTheirMessages`; `SettingsStoreTests.swift testRefusedFilesStayByteIdenticalWithTheirMessages`; `RecentMoleculesTests.swift damagedOversizedAndNewerPayloadsAreRefused`; `MoleculeSettingsTests.swift everyRefusalHasAFixture` |
| Import a small XYZ file from Files: up to 64 KB and 500 atoms of the ten elements | `XYZParserTests.swift theLimitsAreTheClarifiedOnes`; `XYZParserTests.swift theSizeLimitIsInclusive`; `XYZParserTests.swift theAtomLimitIsInclusive`; `MoleculeImportSessionTests.swift testEachValidFixtureImportsWithItsCounts`; `MoleculeImportSessionTests.swift testAnOversizedFileIsRefusedWithoutBeingRead`; `MoleculeImportSessionTests.swift testTheImportButtonsWordsAndTheControlsHoldOnlyReferences` |
| Bonds of an import inferred from the distances between the atoms and marked as inferred | `BondInferenceTests.swift theThresholdIsTheRadiiSumPlusTheTolerance`; `BondInferenceTests.swift theResultIsSortedSingleInferredAndDeterministic`; `BondStyleTests.swift inferredBondsGiveOneThinStick`; `MoleculeWordsTests.swift testThePanelShowsBothStatements` |
| A file that cannot be opened is refused with the reason, and nothing changes | `MoleculeImportSessionTests.swift testEachRefusalShowsItsSentenceAndChangesNothing`; `MoleculeImportTests.swift everyReasonHasItsOwnSentence`; `MoleculeCoreTests.swift testEveryImportRefusalLeavesTheStateUnchanged`; `ImportFuzzTests.swift twoThousandMutatedFilesNeverBreakTheImport` |
| Every element value and molecule structure carries its source and license | `ElementsTests.swift everyStoredValueHasOneSourceRecord`; `ElementAuditTests.swift theBundledDataHasNoProblems`; `ElementAuditTests.swift theCommittedDataSourcesDocumentMatchesTheData`; `MoleculeReviewTests.swift theCommittedDataReviewMatchesTheData` |
| VoiceOver reads every control with its value | `MoleculeRenderTests.swift testTheWordsOfTheControls`; `MoleculeLibraryUITests.swift testEveryLibraryEntrysWords` |
| The canvas is described with the molecule, the display mode and the selected atom | `MoleculeCoreTests.swift testTheLinesAndTheCanvasDescriptionFollowClarificationQ5`; `MoleculeCoreTests.swift testTheDigestAndTheDescriptionCoverThePanAndTheAtom`; `MoleculePanelTests.swift testTheMirrorAndTheDescriptionNameTheSelectedAtom` |
| A newly selected atom is announced | `MoleculePanelTests.swift testEachActionAnnouncesAtMostOnceAndASelectionChangeIsAnnounced` |
| Every gesture has a button that does the same | `MoleculeGestureTests.swift testEveryGestureActionHasANativeControl`; `MoleculeGestureTests.swift testADragThroughTheSessionEqualsPressingTurnLeftThreeTimes` |
| Reopens where you left it | `MoleculeSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `MoleculeCoreTests.swift testTheSnapshotRestoresIdenticallyInAnotherEngine`; `MoleculeImportSessionTests.swift testReopeningShowsTheImportAndTheRecentListHoldsIt`; `MoleculeCoreTests.swift testTheMigrationStepsTurnSchemaOneAndTwoIntoSchemaFour` |
| Nothing is sent anywhere | `RecentStoreTests.swift testWithoutStorageTheListIsKeptInMemory`; `SettingsStoreTests.swift testWithoutStorageTheSettingsAreKeptInMemory` |

The source scan of the experience (`me-no-network`, T-A15-603) also proves that nothing is sent: no network,
tracking, sensor, recording, photo-library, image-picker, brightness or idle-timer use is in
`Packages/ExperiencesCreative/MolecularExplorer` (`.autonomy/checks/A15-P06.me-no-network.json`). See
[privacy-and-credits.md](privacy-and-credits.md), [data-sources.md](data-sources.md) and
[data-review.md](data-review.md). No speed, timing or device claim is made. The interface tests of chunk `w2`
(`MEExploreUITests`, `MELibraryUITests`; T-A15-609) prove the journeys through the app's controls on the iOS 27 phone
simulator without presenting the document picker; they are simulator results, not device measurements. Device
measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
