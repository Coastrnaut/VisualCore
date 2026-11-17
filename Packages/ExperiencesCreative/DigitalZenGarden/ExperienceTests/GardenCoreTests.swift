// GardenCoreTests — feature 146 (A20-P02) T-A20-205 (FR-A20-201, FR-A20-203, FR-A20-205, FR-A20-206; clarifications
// Q2, Q3, Q5; contracts/experience.md "Actions"). The core of Digital Zen Garden: the conformance checks; every action
// in range accepted and changing the digest; refusals out of range, out of order and with nothing to undo or redo,
// each leaving the state as it was; the snapshot (the garden document only) round trip; a stroke at its point cap
// ending there; a stroke at the garden's stroke cap refused with the garden unchanged and its refusal as the outcome;
// the quality tiers. Short runs only.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

@MainActor
@Suite struct GardenCoreTests {
    @Test func conformancePassesOverFourSeeds() async {
        let id = GardenTest.id
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5,
            actions: [ScriptedAction("stroke.begin", [0.2, 0.3, 0]),
                      ScriptedAction("stroke.add", GardenTest.addValues(from: Vec2(0.2, 0.3), to: Vec2(0.7, 0.6))),
                      ScriptedAction("stroke.end"), ScriptedAction("rake.style", [1]),
                      ScriptedAction("sand.tone", [2]), ScriptedAction("stroke.begin", [0.5, 0.5, 1]),
                      ScriptedAction("stroke.end"), ScriptedAction("edit.undo"), ScriptedAction("edit.redo")],
            rejected: [ScriptedAction("stroke.add", [Double](repeating: 0.5, count: 24)),
                       ScriptedAction("stroke.end"), ScriptedAction("edit.undo"), ScriptedAction("edit.redo"),
                       ScriptedAction("rake.style", [0.5]), ScriptedAction("sand.tone", [1.5]),
                       ScriptedAction("stroke.begin", [0.5, 0.5, 0.5]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(GardenCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theOpeningStateAndTheControls() {
        let core = GardenCore()
        #expect(core.document == .empty && !core.isRaking && core.inProgress.isEmpty && core.rakeStyle == 0)
        #expect(core.lastRefusal == nil && core.outcome?.code == "strokes-0")
        #expect(GardenCore.controls.map(\.id) == GardenCore.actionIDs)
        let counts = GardenCore.controls.map(\.ranges.count)
        #expect(counts == [3, 24, 0, 1, 1, 0, 0, 3, 1, 2, 1, 0, 1])
        #expect(GardenCore.controls.allSatisfy { $0.ranges.count <= ExperienceControl.maxValues })
        #expect(GardenCore.qualityTiers == 2)
        #expect(GardenCore.qualityProfile.levels.map(\.name) == ["level-0", "level-1"])
    }

    @Test func everyActionInRangeIsAcceptedAndChangesTheState() throws {
        var core = GardenCore()
        var digest = try gardenDigest(core)
        // The digest is the garden document (what the snapshot keeps): only the actions that change the garden
        // change it; the others change the stroke in progress or the rake style.
        let script: [(String, [Double], Bool)] = [
            ("stroke.begin", [0.2, 0.3, 0], false),
            ("stroke.add", GardenTest.addValues(from: Vec2(0.2, 0.3), to: Vec2(0.8, 0.4)), false),
            ("stroke.end", [], true), ("rake.style", [1], false), ("sand.tone", [2], true), ("edit.undo", [], true),
            ("edit.redo", [], true),
        ]
        for (control, values, changesGarden) in script {
            let (next, result) = gardenApplied(core, control, values)
            #expect(result == .accepted, "\(control)")
            #expect(next != core, "\(control) changes the state")
            let found = try gardenDigest(next)
            #expect((found != digest) == changesGarden, "\(control) and the digest")
            core = next
            digest = found
        }
        #expect(core.document.strokes.count == 1 && core.document.tone == "grey" && core.rakeStyle == 1)
        #expect(core.document.strokes[0].rake == "fine-rake")
        #expect(core.outcome?.code == "strokes-1")
    }

    @Test func refusedActionsLeaveTheStateAsItWas() throws {
        let fresh = GardenCore()
        let refusals: [(String, [Double], String)] = [
            ("stroke.add", [Double](repeating: 0.5, count: 24), "action.rule.a20.no-stroke"),
            ("stroke.end", [], "action.rule.a20.no-stroke"),
            ("edit.undo", [], "action.rule.a20.nothing-to-undo"),
            ("edit.redo", [], "action.rule.a20.nothing-to-redo"),
            ("stroke.begin", [0.5, 0.5, 0.5], "action.rule.a20.invalid-choice"),
            ("rake.style", [0.5], "action.rule.a20.invalid-choice"),
            ("sand.tone", [1.5], "action.rule.a20.invalid-choice"),
            ("stroke.begin", [1.5, 0.5, 0], "action.out-of-range"),
            ("stroke.begin", [0.5, 0.5], "action.wrong-value-count"),
            ("stroke.add", [0.5, 0.5], "action.wrong-value-count"),
            ("sand.tone", [3], "action.out-of-range"),
            ("stroke.begin", [Double.nan, 0.5, 0], "action.non-finite"),
            ("bogus", [], "action.unknown-control"),
        ]
        let before = try gardenDigest(fresh)
        for (control, values, code) in refusals {
            let (next, result) = gardenApplied(fresh, control, values)
            #expect(result.code == code, "\(control) \(values)")
            #expect(next == fresh, "\(control) \(values)")
            #expect(try gardenDigest(next) == before, "\(control) \(values)")
        }
        // A point outside 0…1 in the middle of a stroke.add is refused without keeping the points before it.
        let (raking, begun) = gardenApplied(fresh, "stroke.begin", [0.5, 0.5, 0])
        #expect(begun == .accepted)
        var values = GardenTest.addValues(from: Vec2(0.5, 0.5), to: Vec2(0.6, 0.6))
        values[9] = 1.2
        let (after, result) = gardenApplied(raking, "stroke.add", values)
        #expect(result == .rejected(.outOfRange(index: 9)))
        #expect(after == raking)
    }

    @Test func choosingTheCurrentToneChangesNothing() throws {
        let fresh = GardenCore()
        let (same, result) = gardenApplied(fresh, "sand.tone", [0])
        #expect(result == .accepted)
        #expect(same == fresh && !same.history.canUndo)
        let (warm, _) = gardenApplied(fresh, "sand.tone", [1])
        #expect(warm.document.tone == "warm" && warm.history.canUndo)
        let (undone, _) = gardenApplied(warm, "edit.undo")
        #expect(undone.document.tone == "pale" && undone.history.canRedo)
    }

    @Test func aNewBeginDiscardsTheStrokeInProgressAndRepeatsAreDropped() {
        var core = GardenCore()
        core = gardenApplied(core, "stroke.begin", [0.1, 0.1, 0]).0
        core = gardenApplied(core, "stroke.add", [Double](repeating: 0.3, count: 24)).0
        #expect(core.inProgress == [Vec2(0.1, 0.1), Vec2(0.3, 0.3)], "the eleven repeated pairs are dropped")
        core = gardenApplied(core, "stroke.begin", [0.7, 0.6, 1]).0
        #expect(core.inProgress == [Vec2(0.7, 0.6)] && core.inProgressRake == 1)
        core = gardenApplied(core, "stroke.end").0
        #expect(core.document.strokes.count == 1)
        #expect(core.document.strokes[0].rake == "wide-rake" && core.document.strokes[0].points == [Vec2(0.7, 0.6)])
        #expect(!core.isRaking && core.inProgress.isEmpty)
    }

    @Test func theSnapshotIsTheGardenDocumentOnly() throws {
        var core = GardenCore()
        core = gardenApplied(core, "stroke.begin", [0.2, 0.2, 0]).0
        core = gardenApplied(core, "stroke.add", GardenTest.addValues(from: Vec2(0.2, 0.2), to: Vec2(0.9, 0.7))).0
        core = gardenApplied(core, "stroke.end").0
        core = gardenApplied(core, "sand.tone", [1]).0
        core = gardenApplied(core, "rake.style", [1]).0
        core = gardenApplied(core, "stroke.begin", [0.5, 0.5, 1]).0
        let payload = try core.snapshotPayload()
        let file = try core.document.encoded()
        #expect(payload == file)
        #expect(GardenDocument.decode(payload) == .success(core.document))
        let restored = try GardenCore.restore(payload: payload, seed: 9)
        #expect(restored.document == core.document)
        #expect(!restored.history.canUndo && !restored.history.canRedo, "the undo history restarts")
        #expect(!restored.isRaking && restored.rakeStyle == 0 && restored.lastRefusal == nil)
        #expect(try GardenCore.restore(payload: restored.snapshotPayload(), seed: 1) == restored)
        #expect(throws: DocumentRefusal.damaged) { try GardenCore.restore(payload: Data("{}".utf8), seed: 1) }
        #expect(GardenCore.migrations.currentVersion == 1)
    }

    @Test func aStrokeAtItsPointCapEndsThere() throws {
        var core = gardenApplied(GardenCore(), "stroke.begin", [0.05, 0.05, 0]).0
        // 180 adds of twelve distinct points each: 2,161 raw points offered, 2,048 kept.
        var index = 0
        for add in 0..<180 {
            var values: [Double] = []
            for _ in 0..<GardenCore.pointsPerAdd {
                index += 1
                let x = 0.05 + 0.9 * Double(index % 400) / 400
                let y = 0.05 + 0.9 * Double(index / 400) / 6
                values.append(x)
                values.append(y)
            }
            let (next, result) = gardenApplied(core, "stroke.add", values)
            #expect(result == .accepted, "add \(add)")
            core = next
        }
        #expect(core.inProgress.count == GardenCore.maxRawPoints)
        let pending = try #require(core.pendingStroke)
        #expect(pending.capped && pending.points.count == RakeStroke.maxPoints)
        core = gardenApplied(core, "stroke.end").0
        #expect(core.document.strokes.count == 1)
        #expect(core.document.strokes[0].capped && core.document.strokes[0].points.count == RakeStroke.maxPoints)
        #expect(GardenTest.largestGap(core.document.strokes[0].points) <= StrokeResampler.spacing + 1e-9)
        core = gardenApplied(core, "stroke.begin", [0.5, 0.5, 0]).0
        core = gardenApplied(core, "stroke.end").0
        #expect(core.document.strokes.count == 2, "the next drag starts a new stroke")
    }

    @Test func aStrokeAtTheStrokeCapIsRefusedWithTheGardenUnchanged() throws {
        let full = GardenCore(document: dabGarden(GardenDocument.maxStrokes))
        #expect(full.isAtStrokeCap && full.outcome?.code == "strokes-400")
        var core = gardenApplied(full, "stroke.begin", [0.2, 0.2, 0]).0
        core = gardenApplied(core, "stroke.add", GardenTest.addValues(from: Vec2(0.2, 0.2), to: Vec2(0.4, 0.3))).0
        let (ended, result) = gardenApplied(core, "stroke.end")
        #expect(result == .accepted, "the stroke ends")
        #expect(ended.document == full.document, "the garden is unchanged")
        #expect(ended.lastRefusal == "over-cap" && ended.outcome?.code == "refused-over-cap")
        #expect(!ended.isRaking)
        let (again, _) = gardenApplied(ended, "stroke.begin", [0.5, 0.5, 0])
        #expect(again.lastRefusal == nil && again.isRaking)
        let (undone, _) = gardenApplied(ended, "edit.undo")
        #expect(undone == ended, "a restored garden has nothing to undo")
    }

    @Test func theQualityTierLeavesTheDigest() throws {
        var core = GardenCore()
        core = gardenApplied(core, "sand.tone", [1]).0
        let digest = try gardenDigest(core)
        core.setQualityTier(1)
        let tiered = try gardenDigest(core)
        #expect(core.qualityTier == 1 && tiered == digest)
        core.setQualityTier(7)
        #expect(core.qualityTier == 1)
        core.reset()
        #expect(core.qualityTier == 1 && core.document == .empty)
    }
}
