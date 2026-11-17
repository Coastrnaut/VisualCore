// SnapshotMigrationTests — feature 133 (A18-P03) T-A18-305 (FR-A18-301, FR-A18-306; G-THEMES; clarification Q3;
// contracts/themes.md "Snapshot"; data-model.md "AmbientCore"). Snapshot schema 2 of Ambient Clock: the stored
// schema-1 example (`AmbientCore.schemaOneExample()`) is accepted by the registry's `SnapshotMigrationCheck` and
// restores through the migration to theme 0 and palette 0 with its format, motion and speed kept; a schema-1 payload
// handed to the restore without the migration is refused; the schema-2 example round-trips through two engines with
// its digest; `theme.select` 4 and `theme.palette` 3 are refused as out of range and 1.5 as `a18.invalid-choice`,
// changing nothing; another theme resets the palette to 0 and the same theme keeps it; the outcome names the theme
// (`theme-wave-field`); the digest (domain `a18.ambient.v2`) covers the theme and the palette.
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience

@MainActor
@Suite struct SnapshotMigrationTests {
    @Test func theSchemaIsTwoAndTheSchemaOneExampleIsAcceptedByTheRegistryCheck() async throws {
        #expect(AmbientCore.schemaVersion == 2)
        #expect(AmbientCore.migrations.currentVersion == 2)
        #expect(AmbientCore.digestDomain == "a18.ambient.v2")
        let one = try #require(AmbientCore.schemaOneExample())
        #expect(one.version == 1)
        let problems = await SnapshotMigrationCheck.problems(for: AmbientCore.self, id: AmbientTest.id,
                                                              examples: [one])
        #expect(problems == [])
        // The schema-2 example is of the current schema, which the check refuses as an example.
        let two = try #require(AmbientCore.schemaTwoExample())
        let refused = await SnapshotMigrationCheck.problems(for: AmbientCore.self, id: AmbientTest.id,
                                                             examples: [one, two])
        #expect(refused == ["version 2: not an earlier version (current is 2)"])
        #expect(AmbientCore.schemaExample(version: 3) == nil)
        #expect(AmbientCore.schemaExamplePayload(version: 0) == nil)
    }

    @Test func theSchemaOneExampleMigratesToThemeZeroPaletteZeroKeepingTheOtherFields() async throws {
        let one = try #require(AmbientCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: one.snapshot)
        #expect(snapshot.schemaVersion == 1)
        let payload = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
            as? [String: Any])
        #expect(Set(payload.keys) == ["hourCycle", "motion", "showDate", "showSeconds", "speed"])
        var engine = try await AmbientTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(core.theme == 0 && core.palette == 0)
        #expect(core.hourCycle == 2 && core.showSeconds && !core.showDate)
        #expect(core.motion && core.speed == 1.5)
        #expect(core.instant == 0 && core.revision == 0)
        #expect(try engine.digest().hex == one.expectedDigest)
        let expected = AmbientCore(hourCycle: 2, showSeconds: true, showDate: false, motion: true, speed: 1.5)
        #expect(core == expected)
        // After the migration the state is written as schema 2, with the theme and the palette.
        let written = try core.snapshotPayload()
        let object = try #require(try JSONSerialization.jsonObject(with: written) as? [String: Any])
        #expect(Set(object.keys) == ["hourCycle", "motion", "palette", "showDate", "showSeconds", "speed", "theme"])
        #expect(object["theme"] as? Int == 0 && object["palette"] as? Int == 0)
    }

    @Test func aSchemaOnePayloadNeedsTheMigration() throws {
        let one = try #require(AmbientCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: one.snapshot)
        #expect(throws: (any Error).self) {
            _ = try AmbientCore.restore(payload: Data(snapshot.payload.utf8), seed: 7)
        }
    }

    @Test func theSchemaTwoExampleRoundTripsThroughTwoEngines() async throws {
        let two = try #require(AmbientCore.schemaTwoExample())
        let snapshot = try ExperienceSnapshot(data: two.snapshot)
        #expect(snapshot.schemaVersion == 2)
        var first = try await AmbientTest.engine(seed: snapshot.seed)
        try first.restore(snapshot)
        let core = try #require(first.core)
        #expect(core.theme == 2 && core.palette == 1)
        #expect(core.hourCycle == 2 && core.showSeconds && !core.showDate && core.motion && core.speed == 1.5)
        #expect(try first.digest().hex == two.expectedDigest)
        #expect(core.outcome?.code == "theme-wave-field")
        let again = try first.snapshot()
        var second = try await AmbientTest.engine(seed: snapshot.seed)
        try second.restore(again)
        #expect(second.core == first.core)
        #expect(try second.digest() == first.digest())
        // The payload round trip is exact.
        let payload = try core.snapshotPayload()
        let restored = try AmbientCore.restore(payload: payload, seed: 1)
        #expect(try restored.snapshotPayload() == payload)
        #expect(try ambientDigest(restored) == ambientDigest(core))
    }

    @Test func aStoredThemeOrPaletteOutsideItsRangeIsRefused() {
        let theme = Data(#"{"hourCycle":0,"motion":true,"palette":0,"showDate":true,"showSeconds":false,"speed":1,"theme":4}"#
            .utf8)
        #expect(throws: AmbientRestoreError.outOfRange("theme")) {
            _ = try AmbientCore.restore(payload: theme, seed: 1)
        }
        let palette = Data(#"{"hourCycle":0,"motion":true,"palette":3,"showDate":true,"showSeconds":false,"speed":1,"theme":1}"#
            .utf8)
        #expect(throws: AmbientRestoreError.outOfRange("palette")) {
            _ = try AmbientCore.restore(payload: palette, seed: 1)
        }
    }

    @Test func aThemeOrPaletteOutsideItsRangeIsRefusedAndChangesNothing() async throws {
        let cases: [(String, Double)] = [("theme.select", 4), ("theme.select", -1), ("theme.palette", 3),
                                         ("theme.palette", -1)]
        for (control, value) in cases {
            var engine = try await AmbientTest.engine()
            let before = try #require(engine.core)
            let digest = try engine.digest()
            let result = engine.handle(control: control, values: [value])
            #expect(!result.isAccepted, "\(control) \(value)")
            #expect(engine.core == before, "\(control) \(value)")
            #expect(try engine.digest() == digest, "\(control) \(value)")
        }
    }

    @Test func aChoiceThatIsNotAWholeIndexIsAnInvalidChoice() async throws {
        let invalid = ActionResult.rejected(.rule(code: AmbientRule.invalidChoice))
        let cases: [(String, Double)] = [("theme.select", 1.5), ("theme.palette", 0.5), ("theme.palette", 1.5)]
        for (control, value) in cases {
            var engine = try await AmbientTest.engine()
            let before = try #require(engine.core)
            let result = engine.handle(control: control, values: [value])
            #expect(result == invalid, "\(control) \(value)")
            #expect(engine.core == before, "\(control) \(value)")
            let (direct, directResult) = ambientApplied(AmbientCore(), control, [value])
            #expect(directResult == invalid, "\(control) \(value)")
            #expect(direct == AmbientCore(), "\(control) \(value)")
        }
        let (_, count) = ambientApplied(AmbientCore(), "theme.select", [1, 2])
        #expect(!count.isAccepted)
        let (_, nonFinite) = ambientApplied(AmbientCore(), "theme.palette", [.nan])
        #expect(!nonFinite.isAccepted)
    }

    @Test func anotherThemeResetsThePaletteAndTheSameThemeKeepsIt() {
        var core = AmbientCore()
        let steps: [(String, Double, Int, Int)] = [("theme.select", 2, 2, 0), ("theme.palette", 2, 2, 2),
                                                   ("theme.select", 2, 2, 2), ("theme.select", 3, 3, 0),
                                                   ("theme.palette", 1, 3, 1), ("theme.select", 0, 0, 0)]
        for (control, value, theme, palette) in steps {
            let (next, result) = ambientApplied(core, control, [value])
            #expect(result == .accepted, "\(control) \(value)")
            #expect(next.theme == theme && next.palette == palette, "\(control) \(value)")
            core = next
        }
    }

    @Test func theOutcomeNamesTheTheme() {
        let expected = ["showing-time", "theme-particle-drift", "theme-wave-field", "theme-sdf-shapes"]
        for theme in 0..<expected.count {
            let (core, result) = ambientApplied(AmbientCore(), "theme.select", [Double(theme)])
            #expect(result == .accepted)
            #expect(core.outcome?.code == expected[theme], "theme \(theme)")
            let (still, _) = ambientApplied(core, "theme.motion", [0])
            #expect(still.outcome?.code == "motion-off", "theme \(theme)")
        }
    }

    @Test func theDigestCoversTheThemeAndThePalette() throws {
        let base = AmbientCore()
        let (wave, _) = ambientApplied(base, "theme.select", [2])
        let (lagoon, _) = ambientApplied(wave, "theme.palette", [1])
        let digests = try [base, wave, lagoon].map { try ambientDigest($0) }
        #expect(Set(digests).count == 3)
        let made = AmbientCore(hourCycle: 0, showSeconds: false, showDate: true, motion: true, speed: 1, theme: 2,
                               palette: 1)
        #expect(made == lagoon)
        #expect(try ambientDigest(made) == ambientDigest(lagoon))
        let clamped = AmbientCore(hourCycle: 0, showSeconds: false, showDate: true, motion: true, speed: 1, theme: 9,
                                  palette: -2)
        #expect(clamped.theme == 3 && clamped.palette == 0)
    }
}
