// SandSceneTests — feature 146 (A20-P02) T-A20-205 (FR-A20-202, FR-A20-203, FR-A20-207; SC-A20-202, SC-A20-203;
// clarification Q1; contracts/experience.md "Sand"). The sand drawn inside the one app's session host on the simulator,
// short runs only (small canvases, no sleep, no wall-clock assertion): the drawn target read back with
// `readFloatPixels` matches the CPU field (the core's strokes replayed at 480 × 360) within 1/1024 in `rgba16f` and
// within 1/255 in the forced `rgba8` fallback; the stroke in progress is drawn over the base; undo, redo and a restore
// rebuild the field equal to a fresh replay; a context recreation draws the same frame; a still garden is not drawn
// again until something changes; both levels draw a dark surround; closing leaves no GPU object.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct SandSceneTests {
    /// The CPU reference of the drawn field for `core`: its strokes replayed at 480 × 360, with the stroke in
    /// progress stamped over them.
    private func reference(_ core: GardenCore) -> SandField {
        var field = SandField.replay(core.document.strokes, columns: SandScene.columns, rows: SandScene.rows)
        if let pending = core.pendingStroke { field.apply(pending) }
        return field
    }

    /// The tolerance of a target of `format`: 1/1024 for `rgba16f`, 1/255 for `rgba8`.
    private func tolerance(_ format: TextureFormat) -> Float {
        format == .rgba16f ? 1.0 / 1024 : 1.0 / 255
    }

    /// Checks that the drawn target of `shell` holds the reference field of its core within the tolerance.
    private func expectDrawnMatches(_ shell: ExperienceShell<GardenPresenter>, _ note: String) throws {
        let sand = try #require(shell.presenter.sand, "\(note)")
        let core = try GardenTest.core(shell)
        let expected = reference(core)
        #expect(sand.shown == expected, "\(note): the CPU field is the replay")
        let target = try #require(sand.target, "\(note)")
        let read = target.readFloatPixels()
        let difference = SandScene.maxDifference(read, field: expected, format: sand.format)
        #expect(difference <= tolerance(sand.format), "\(note): read back differs by \(difference)")
    }

    @Test func theDrawnTargetMatchesTheCPUFieldInHalfFloat() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        let sand = try #require(shell.presenter.sand)
        #expect(sand.format == .rgba16f, "the simulator renders half floats")
        GardenTest.rake(shell, from: Vec2(0.1, 0.4), to: Vec2(0.9, 0.5))
        try GardenTest.draw(session)
        GardenTest.rake(shell, from: Vec2(0.5, 0.1), to: Vec2(0.45, 0.9), rake: 1)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "two strokes")
        #expect(sand.commitCount == 2, "each stroke was stamped into the base once")
        let core = try GardenTest.core(shell)
        #expect(sand.base.maxDifference(SandField(columns: 480, rows: 360)) > 0.5, "the grooves are deep")
        #expect(core.document.strokes.count == 2)
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func theForcedFallbackMatchesWithinOneStep() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session, forceFallback: true)
        let sand = try #require(shell.presenter.sand)
        #expect(sand.format == .rgba8)
        GardenTest.rake(shell, from: Vec2(0.2, 0.2), to: Vec2(0.8, 0.8), rake: 1)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "rgba8")
        let frame = try GardenTest.picture(session)
        #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height))
        session.close()
    }

    @Test func theStrokeInProgressIsDrawnOverTheBase() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        GardenTest.rake(shell, from: Vec2(0.1, 0.3), to: Vec2(0.9, 0.3))
        #expect(shell.handle(control: "stroke.begin", values: [0.3, 0.1, 1]) == .accepted)
        #expect(shell.handle(control: "stroke.add",
                             values: GardenTest.addValues(from: Vec2(0.3, 0.1), to: Vec2(0.35, 0.9))) == .accepted)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "in progress")
        let sand = try #require(shell.presenter.sand)
        #expect(sand.shownPending != nil && sand.baseStrokes.count == 1)
        #expect(shell.handle(control: "stroke.end") == .accepted)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "committed")
        #expect(sand.shownPending == nil && sand.baseStrokes.count == 2)
        session.close()
    }

    @Test func undoRedoAndRestoreRebuildTheFieldByReplay() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        GardenTest.rake(shell, from: Vec2(0.1, 0.5), to: Vec2(0.9, 0.5))
        GardenTest.rake(shell, from: Vec2(0.5, 0.1), to: Vec2(0.5, 0.9), rake: 1)
        try GardenTest.draw(session)
        let sand = try #require(shell.presenter.sand)
        let replays = sand.replayCount
        #expect(shell.handle(control: "edit.undo") == .accepted)
        try GardenTest.draw(session)
        #expect(sand.replayCount == replays + 1)
        try expectDrawnMatches(shell, "undo")
        #expect(sand.baseStrokes.count == 1)
        #expect(shell.handle(control: "edit.redo") == .accepted)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "redo")
        #expect(sand.baseStrokes.count == 2)
        let snapshot = try shell.snapshot()
        #expect(shell.handle(control: "edit.undo") == .accepted)
        #expect(shell.handle(control: "edit.undo") == .accepted)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "both undone")
        try shell.restore(snapshot)
        try GardenTest.draw(session)
        try expectDrawnMatches(shell, "restore")
        #expect(sand.baseStrokes.count == 2)
        session.close()
    }

    @Test func aContextRecreationDrawsTheSameFrame() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        GardenTest.rake(shell, from: Vec2(0.15, 0.3), to: Vec2(0.85, 0.7))
        #expect(shell.handle(control: "sand.tone", values: [1]) == .accepted)
        let before = try GardenTest.picture(session)
        let setups = shell.presenter.setupCount
        session.recreateContext()
        #expect(session.state == .running)
        #expect(shell.presenter.setupCount == setups + 1, "setup rebuilt the scenes")
        let after = try GardenTest.picture(session)
        #expect(after.width == before.width && after.height == before.height)
        #expect(after.rgba == before.rgba, "the same frame")
        try expectDrawnMatches(shell, "after recreation")
        session.close()
        let counts = try #require(session.diagnostics.lastCloseCounts)
        #expect(counts.objects == 0 && counts.leaked == 0)
    }

    @Test func aStillGardenIsDrawnOnceUntilSomethingChanges() async throws {
        let session = ExperienceSession()
        let shell = try await GardenTest.open(session)
        #expect(shell.presenter.maxFramesPerSecond == 30)
        try GardenTest.draw(session)
        let cache = try #require(shell.presenter.cache)
        let sand = try #require(shell.presenter.sand)
        let draws = cache.childDrawCount
        let uploads = sand.uploadCount
        let first = try GardenTest.picture(session)
        for _ in 0..<3 { try GardenTest.draw(session) }
        let still = try GardenTest.picture(session)
        #expect(cache.childDrawCount == draws, "no redraw without a change")
        #expect(sand.uploadCount == uploads, "no upload without a change")
        #expect(still.rgba == first.rgba, "the cached picture is the drawn one")
        GardenTest.rake(shell, from: Vec2(0.2, 0.5), to: Vec2(0.8, 0.5))
        let raked = try GardenTest.picture(session)
        #expect(cache.childDrawCount == draws + 1 && sand.uploadCount == uploads + 1)
        #expect(GardenTest.differingPixels(raked.rgba, first.rgba) > 0, "the grooves are drawn")
        #expect(shell.handle(control: "sand.tone", values: [2]) == .accepted)
        try GardenTest.draw(session)
        #expect(cache.childDrawCount == draws + 2, "a tone change draws again")
        #expect(sand.uploadCount == uploads + 1, "the field did not change")
        session.close()
    }

    @Test func bothLevelsDrawADarkSurroundAndTheGrainOnlyAtLevelOne() async throws {
        var pictures: [GardenFrame] = []
        for level in 0..<2 {
            let session = ExperienceSession()
            session.qualityPin = level
            let shell = try await GardenTest.open(session)
            let frame = try GardenTest.picture(session)
            #expect(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "level-\(level)")
            for probe in shell.frameProbes {
                let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
                #expect(found?.rawValue == probe.expected, "level-\(level) \(probe.name)")
            }
            #expect(shell.presenter.sand?.grain == (level == 0))
            pictures.append(frame)
            session.close()
        }
        #expect(GardenTest.differingPixels(pictures[0].rgba, pictures[1].rgba) > 0, "the grain changes the sand")
    }

    @Test func uploadValuesAreRowsBottomUpAndDecodeBack() {
        var field = SandField(columns: 3, rows: 2)
        field[0, 0] = 0.5
        field[2, 1] = -1
        let half = SandScene.uploadValues(field, format: .rgba16f)
        #expect(half.count == 24)
        #expect(half[0] == 0 && half[8] == -1, "GL row 0 is the field's bottom row")
        #expect(half[12] == 0.5 && half[15] == 1)
        let bytes = SandScene.uploadValues(field, format: .rgba8)
        #expect(bytes[8] == 0 && bytes[12] == 0.75)
        #expect(SandScene.maxDifference(half, field: field, format: .rgba16f) == 0)
        #expect(SandScene.maxDifference(bytes, field: field, format: .rgba8) == 0)
        #expect(SandScene.maxDifference([], field: field, format: .rgba8) == .infinity)
    }
}
