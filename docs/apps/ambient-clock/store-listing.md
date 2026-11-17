# Ambient Clock — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Ambient Clock is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 136
(A18-P06), FR-A18-605 and FR-A18-606.

Every sentence below describes something that exists in the controls (`AmbientClock/Experience/AmbientControls.swift`),
the canvas (`AmbientPresenter.swift`), the time overlay (`ClockOverlay.swift`) or the adapter
(`Experience/Adapter/AmbientCore.swift`), and is exercised by the tests named in the traceability table. The text is
checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` (no word is allowed for this
experience: [release.json](release.json) has no `copyCheck.allow`) and by the experience's own word scan of T-A18-607
(`specs/136-ac-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no performance figure and no value from a device, and makes no claim beyond what the code holds.

## Text

**Ambient Clock** — a calm, readable clock over slow backgrounds made entirely in code, inside VisualCore.

The clock shows the system time and date of your device, in the format of your region and language. Choose the
system, 12-hour or 24-hour clock, and show or hide the seconds and the date line.

The time follows the device: it changes with the time zone, with daylight saving time, with a change of region or
language, and when you come back to the clock.

Four backgrounds drawn in code: Noise Gradient, Particle Drift, Wave Field and SDF Shapes, each with three palettes.
A change of background fades from one to the next. Turn motion off for a still picture, or set how fast the
background moves.

Night mode dims the background and warms the colours, with the time in warm amber. Turn it on, or schedule it for the
hours you choose. It changes only the drawing and never your screen brightness setting.

Save up to 12 favourites of a background, its palette, speed and motion, and apply one again with a tap.

Reduce motion keeps the background still and the clock in place; the system's Reduce Motion setting does the same.
The time moves a few points slowly over the screen and the picture dims a little after ten minutes without a touch.

An optional setting keeps the screen on while the clock is open. It is off until you turn it on.

The time is large and white on dark colours, and fits on one line even at the largest text size. VoiceOver speaks the
time, and the date when it is shown.

The clock reopens with the settings you left. It needs no permission.

## Traceability

| Claim | Proving test |
|---|---|
| Slow backgrounds made entirely in code | `ThemeRenderTests.swift everyThemeAtBothLevelsIsNotBlankWithADarkCentreAndItsBudget`; `AmbientRenderTests.swift theFramesAtBothLevelsAreNotBlankAndTheCentreIsDark` |
| The clock shows the system time and date of the device | `PresenterClockTests.swift tickSendsTheClocksInstantAndReturnsTheNextWholeMinute`; `OverlayTests.swift theTextAfterATickIsTheFormattersForEveryZoneAndFormat`; `OverlayTests.swift aTimeSetSentByAnyoneIsShown`; `ACPowerUITests` (the canvas is labelled with a time) |
| In the format of your region and language | `FormatterTests.swift theLocalesUseTheirOwnHourCycle`; `FormatterTests.swift arabicUsesArabicIndicDigitsEverywhere`; `FormatterTests.swift dateOnNamesTheDay` |
| The system, 12-hour or 24-hour clock; seconds and the date line shown or hidden | `FormatterTests.swift templatesFollowTheHourCycleAndSeconds`; `FormatterTests.swift secondsAddTheSecondField`; `FormatterTests.swift dateOffIsEmpty`; `PresenterClockTests.swift withSecondsShownTheDeadlineIsTheNextWholeSecond`; `AmbientCoreTests.swift acceptedActionsSetTheFields` |
| The time follows a change of time zone | `TimeZoneChangeTests.swift aZoneChangeSendsOneTimeChangeAndShowsKolkataTimeForTheSameInstant`; `PresenterClockTests.swift aZoneTheProviderReportsIsAdoptedAtTheNextTick`; `StateTests.swift aNewSystemZoneMovesTheTimeUnderTheSystemPolicy` |
| The time follows daylight saving time | `DaylightSavingTests.swift springForwardNeverShowsTheMissingHour`; `DaylightSavingTests.swift fallBackShowsTheRepeatedMinuteTwice`; `DaylightSavingTests.swift deadlinesAlwaysIncreaseAcrossBothChanges` |
| The time follows a change of region or language | `TimeZoneChangeTests.swift aLocaleChangeReformatsTheText`; `StateTests.swift aNewSystemLocaleReformatsUnderTheSystemPolicy` |
| The time is brought up to date when you come back to the clock | `ResumeTests.swift theReturnToTheForegroundShowsTheNewTimeBeforeAnyDraw`; `TimeZoneChangeTests.swift theReturnToTheForegroundSendsOneTimeChange` |
| Four backgrounds (Noise Gradient, Particle Drift, Wave Field, SDF Shapes), each with three palettes | `ThemeCatalogTests.swift theCatalogHasFourThemesOfThreePalettesOfFourColours`; `ThemeRenderTests.swift theThreeNewThemesDifferFromTheNoiseGradient`; `ACThemeUITests` (the theme menu is set to "Wave Field") |
| A change of background fades from one to the next | `CrossfadeUseTests.swift withoutReduceMotionTheFadeMixesAndEndsOnTheNewTheme`; `CrossfadeUseTests.swift aPaletteChangeFadesAndEndsOnThePalette` |
| Motion off gives a still picture; the speed is set by the person | `AmbientRenderTests.swift withMotionOffTwoFramesAtDifferentTimesAreIdentical`; `AmbientRenderTests.swift withMotionOnTwoFramesAtDifferentTimesDiffer`; `ThemeTests.swift theUniformTimeIsTheFrameTimeTimesTheSpeedWithMotionOn`; `AmbientCoreTests.swift everyControlIsAcceptedInsideItsRanges` |
| Night mode dims the background and warms the colours, with the time in warm amber | `NightRenderTests.swift nightModeOnDrawsADarkerFrameThatIsNotBlank`; `NightRenderTests.swift theOverlayTextIsAmberAtNightAndWhiteByDay`; `NightPolicyTests.swift aNightColourIsDarkerThanItsDayColour`; `ACPowerUITests` (night mode chosen On) |
| Night mode on, or scheduled for the hours you choose | `NightRenderTests.swift aScheduledWindowIsNightAtElevenPMAndDayAtNoonInTheDisplayZone`; `NightPolicyTests.swift aWindowAcrossMidnightIncludesItsStartAndExcludesItsEnd`; `PowerCoreTests.swift everyNewControlIsAcceptedInsideItsRange` |
| Never your screen brightness setting | `SourceScanTests.swift noSourceWritesABrightness` |
| Up to 12 favourites of a background, its palette, speed and motion, applied again with a tap | `FavouritesTests.swift aSavedFavouriteIsReadAgainAndApplyRestoresItsPreset`; `FavouritesTests.swift aThirteenthFavouriteIsRefusedAsOverCap`; `ACThemeUITests` (Wave Field saved as "Evening", the theme switched, "Evening" applied, Wave Field shown again) |
| Reduce motion keeps the background still and the clock in place; the system setting does the same | `PowerCoreTests.swift inAppReducedMotionStillsTheThemeAndCutsAThemeChange`; `AmbientRenderTests.swift withReduceMotionTwoFramesAtDifferentTimesAreIdentical`; `CrossfadeUseTests.swift underReduceMotionAThemeChangeShowsTheNewThemeOnTheNextFrame`; `ScreenCareTests.swift theDriftIsDeterministicAndZeroUnderReducedMotion`; `ACPowerUITests` (reduced motion switched on) |
| The time moves a few points slowly over the screen | `ScreenCareTests.swift theDriftIsBoundedAndSlowOverADay`; `ScreenCareTests.swift theConstantsAreTheDocumentedValues` |
| The picture dims a little after ten minutes without a touch | `ScreenCareTests.swift theIdleDimStartsAtSixHundredSecondsAndANewActionRestoresIt`; `ResumeTests.swift theDimFactorIsSixTenthsAfterTenIdleMinutesAndOneAfterAnAction` |
| An optional setting keeps the screen on while the clock is open; it is off until you turn it on | `KeepAwakeTests.swift withTheSettingOffThePortIsNeverSetToTrue`; `KeepAwakeTests.swift withTheSettingOnThePortFollowsEveryTransition`; `PowerCoreTests.swift theEarlierExamplesMigrateToSchemaThreeWithTheDefaults`; `SourceScanTests.swift theIdleTimerIsNamedOnlyInKeepAwake` |
| The time is large and white on dark colours | `ThemeCatalogTests.swift whiteTextReachesTheRequiredContrastOnEveryColour`; `ThemeTests.swift everyPaletteColourIsDark`; `OverlayTests.swift atTheDefaultTextSizeTheTimeIsAShareOfTheShorterSide` |
| Fits on one line even at the largest text size | `OverlayTests.swift theLargestTextFitsOneLineWithinNinetyPercentOfTheWidth` |
| VoiceOver speaks the time, and the date when it is shown | `SpokenTimeTests.swift spokenNamesTheTimeAndTheDateInEachLocale`; `SpokenTimeTests.swift spokenIsTheTimeAloneWhenTheDateIsHidden`; `ACPowerUITests` (the canvas label is the spoken time) |
| Reopens with the settings you left | `AmbientCoreTests.swift anEngineSnapshotRestoresIntoAnotherEngine`; `PowerCoreTests.swift theSchemaThreeExampleRoundTrips`; `SnapshotMigrationTests.swift theSchemaTwoExampleRoundTripsThroughTwoEngines`; `ACPowerUITests` (night mode and reduced motion come back after a relaunch) |
| Needs no permission | `ACPowerUITests` (the clock opens with its time on a fresh start); the registration's `"permissions": []` in `Catalog/registrations.json` |

The source scan of the experience (`ac-no-network`, T-A18-603) proves that no network, tracking, sensor, recording,
photo-library, image-picker or brightness use is in `Packages/ExperiencesCreative/AmbientClock`, and that the idle
timer is named only in `Experience/KeepAwake.swift` (`.autonomy/checks/A18-P06.ac-no-network.json`). See
[privacy-and-credits.md](privacy-and-credits.md) and [licenses.md](licenses.md). No speed, timing, heat or device claim
is made. The interface tests of chunk `z2` (`ACPowerUITests`, `ACThemeUITests`; T-A18-608) prove the journeys through
the app's controls on the iOS 27 phone simulator; they are simulator results, not device measurements. Device
measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
