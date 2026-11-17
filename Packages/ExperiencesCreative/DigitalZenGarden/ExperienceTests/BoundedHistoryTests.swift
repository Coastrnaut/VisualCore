// BoundedHistoryTests — feature 148 (A20-P04) T-A20-404 (FR-A20-404; SC-A20-402; clarification Q2; contracts/library.md
// "Bounded history"; the manual's regression fixture "memory remains bounded for long gesture histories"). 10,000
// seeded commands of every kind (strokes of at most 64 raw points, stone places, moves, turns and removals, tone
// changes, undo and redo) applied to the experience's core through its actions leave, after every command, at most
// 100 undoable commands, a stroke in progress of at most 2,048 raw points and a document within its caps (400
// strokes, 24 stones); the encoded history (its done and undone lists as JSON) stays under the arithmetic bound
// 100 × 512 points × 2 coordinates × 24 bytes = 2,457,600 bytes; the stroke cap and the stone cap refuse beyond 400
// strokes and 24 stones; and undoing every undoable command ends exactly at the checkpoint, never past it. The bound
// is arithmetic on the encoded size (no wall-clock or memory-gauge measurement); the run is short.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

/// A seeded generator (SplitMix64), so the command sequence is the same on every run.
struct GardenSeededGenerator {
    private var state: UInt64

    /// A generator starting at `seed`.
    init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in 0..<`bound`.
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(max(bound, 1))) }

    /// A number in `range`.
    mutating func unit(_ range: ClosedRange<Double> = 0...1) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * (Double(next() >> 11) / Double(1 << 53))
    }
}

@MainActor
@Suite struct BoundedHistoryTests {
    /// The arithmetic bound of the encoded history: 100 commands × 512 points × 2 coordinates × 24 bytes.
    static let byteBound = GardenHistory.maxUndo * RakeStroke.maxPoints * 2 * 24
    /// The number of commands of the fixture.
    static let commandCount = 10_000
    /// The most raw points of one stroke of the fixture.
    static let maxStrokePoints = 64

    /// The encoded size of `history`'s done and undone lists.
    static func encodedBytes(_ history: GardenHistory) throws -> Int {
        let encoder = JSONEncoder()
        return try encoder.encode(history.done).count + encoder.encode(history.undone).count
    }

    /// Applies `control` with `values` to `core` and returns the result.
    @discardableResult
    static func apply(_ core: inout GardenCore, _ control: String, _ values: [Double] = []) -> ActionResult {
        core.apply(ExperienceAction(control: control, values: values, step: 0))
    }

    /// Rakes one stroke of 1…64 raw points as a short random walk from a seeded start; returns whether the stroke was
    /// refused at the stroke cap.
    static func rake(_ core: inout GardenCore, _ random: inout GardenSeededGenerator) -> Bool {
        var point = Vec2(random.unit(0.1...0.9), random.unit(0.1...0.9))
        apply(&core, "stroke.begin", [point.x, point.y, Double(random.below(2))])
        let adds = random.below(6)   // 0…5 adds of 12 points: at most 61 raw points
        for _ in 0..<adds {
            var values: [Double] = []
            for _ in 0..<GardenCore.pointsPerAdd {
                point = TrayClamp.clamped(point.x + random.unit(-0.004...0.004), point.y + random.unit(-0.004...0.004))
                values.append(point.x)
                values.append(point.y)
            }
            apply(&core, "stroke.add", values)
        }
        #expect(core.inProgress.count <= maxStrokePoints)
        apply(&core, "stroke.end")
        return core.lastRefusal == "over-cap"
    }

    /// Selects a seeded stone of `core`; returns false without stones.
    static func selectStone(_ core: inout GardenCore, _ random: inout GardenSeededGenerator) -> Bool {
        let stones = core.document.stones
        guard !stones.isEmpty else { return false }
        return apply(&core, "stone.select", [Double(stones[random.below(stones.count)].id)]).isAccepted
    }

    @Test func tenThousandCommandsStayWithinTheBounds() throws {
        #expect(Self.byteBound == 2_457_600)
        var random = GardenSeededGenerator(seed: 0xA20_0404)
        var core = GardenCore()
        var strokeRefusals = 0
        var stoneRefusals = 0
        var kinds = Set<String>()
        var largestEncoded = 0
        for index in 0..<Self.commandCount {
            let roll = random.below(100)
            switch roll {
            case 0..<35:
                if Self.rake(&core, &random) { strokeRefusals += 1 }
                kinds.insert("rake")
            case 35..<52:
                let result = Self.apply(&core, "stone.place",
                                        [Double(random.below(GardenPalette.stones.count)), random.unit(), random.unit()])
                if result.code == "action.rule." + GardenRule.stoneCap { stoneRefusals += 1 }
                kinds.insert("place")
            case 52..<60:
                if Self.selectStone(&core, &random) {
                    Self.apply(&core, "stone.move", [random.unit(), random.unit()])
                    kinds.insert("move")
                }
            case 60..<68:
                if Self.selectStone(&core, &random) {
                    Self.apply(&core, "stone.rotate", [random.unit(-Double.pi...Double.pi)])
                    kinds.insert("rotate")
                }
            case 68..<72:
                if Self.selectStone(&core, &random) {
                    Self.apply(&core, "stone.remove")
                    kinds.insert("remove")
                }
            case 72..<80:
                Self.apply(&core, "sand.tone", [Double(random.below(GardenPalette.tones.count))])
                kinds.insert("tone")
            case 80..<92:
                Self.apply(&core, "edit.undo")
                kinds.insert("undo")
            default:
                Self.apply(&core, "edit.redo")
                kinds.insert("redo")
            }
            let history = core.history
            let document = history.document
            if history.done.count > GardenHistory.maxUndo || core.inProgress.count > GardenCore.maxRawPoints
                || document.strokes.count > GardenDocument.maxStrokes || document.stones.count > GardenDocument.maxStones {
                Issue.record("a bound is exceeded after command \(index)")
                break
            }
            if index % 500 == 499 {
                let bytes = try Self.encodedBytes(history)
                largestEncoded = max(largestEncoded, bytes)
                #expect(bytes < Self.byteBound, "encoded history \(bytes) bytes after command \(index)")
                #expect(document.validate() == nil, "document valid after command \(index)")
            }
        }
        #expect(kinds == ["rake", "place", "move", "rotate", "remove", "tone", "undo", "redo"])
        #expect(strokeRefusals > 0, "the stroke cap refused beyond 400 strokes")
        #expect(stoneRefusals > 0, "the stone cap refused beyond 24 stones")
        #expect(largestEncoded > 0 && largestEncoded < Self.byteBound)
        #expect(try Self.encodedBytes(core.history) < Self.byteBound)
        #expect(core.history.done.count == GardenHistory.maxUndo, "the history is full after 10,000 commands")

        // Undo never reaches past the checkpoint.
        var undone = 0
        while core.history.canUndo {
            Self.apply(&core, "edit.undo")
            undone += 1
        }
        #expect(undone <= GardenHistory.maxUndo)
        #expect(Self.apply(&core, "edit.undo").code == "action.rule." + GardenRule.nothingToUndo)
        #expect(core.document == core.history.checkpoint.document)
        #expect(core.document.validate() == nil)
    }

    @Test func aLongStrokeInProgressStopsAtItsPointCap() {
        var core = GardenCore()
        Self.apply(&core, "stroke.begin", [0.1, 0.1, 0])
        var x = 0.1
        for _ in 0..<200 {
            var values: [Double] = []
            for _ in 0..<GardenCore.pointsPerAdd {
                x = x < 0.9 ? x + 0.0005 : 0.1
                values.append(x)
                values.append(0.5)
            }
            Self.apply(&core, "stroke.add", values)
        }
        #expect(core.inProgress.count == GardenCore.maxRawPoints)
        Self.apply(&core, "stroke.end")
        let stroke = core.document.strokes.last
        #expect(stroke.map { $0.points.count <= RakeStroke.maxPoints } == true)
        #expect(core.inProgress.isEmpty && core.history.done.count == 1)
    }
}
