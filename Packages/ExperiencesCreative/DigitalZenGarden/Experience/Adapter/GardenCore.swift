// GardenCore — feature 146 (A20-P02) T-A20-204 (FR-A20-201, FR-A20-203, FR-A20-205, FR-A20-206; clarifications Q2,
// Q3, Q5; data-model.md "GardenCore"; contracts/experience.md "Actions"). The state of Digital Zen Garden as an
// experience: the A20-P01 command history (`GardenHistory`, which holds the garden document), the stroke in progress
// (its raw points, at most 2,048, and its rake), the chosen rake style and the refusal of the last stroke. The core
// never draws and reads no clock; the presenter (`GardenPresenter`) draws it with `SandScene`.
//
// Actions (the engine refuses a value outside the declared range, a non-finite value and a wrong value count before
// the core sees it; called directly, the core refuses them itself with the same reasons):
//   stroke.begin [x 0…1, y 0…1, rake 0…1]  starts a stroke at (x, y) in normalized tray coordinates with the rake 0
//                                          (fine) or 1 (wide), a whole index (`a20.invalid-choice` otherwise). A
//                                          stroke still in progress is discarded (it was never committed).
//   stroke.add [24 × 0…1]                  twelve points x, y of the stroke in progress; unused pairs repeat the
//                                          last point. A point closer than `StrokeResampler.repeatDistance` to the
//                                          last kept point is dropped; points beyond `maxRawPoints` are dropped, so a
//                                          stroke at its point cap ends there. Without a stroke `a20.no-stroke`.
//   stroke.end []                          commits the stroke in progress through `GardenHistory.rake(_:rake:)` (the
//                                          resampler spaces it, at most 512 points). The stroke ends either way; a
//                                          stroke the history refuses (the garden at 400 strokes) leaves the garden
//                                          unchanged and its refusal code in `lastRefusal` (cleared by the next
//                                          accepted action other than `stroke.add`). Without a stroke
//                                          `a20.no-stroke`.
//   rake.style [0…1]                       the rake of the next stroke, a whole index (`a20.invalid-choice`).
//   sand.tone [0…2]                        the sand tone, a whole index of `GardenPalette.tones` (`a20.invalid-choice`);
//                                          a change is an undoable command, choosing the current tone changes nothing.
//   edit.undo [] / edit.redo []            undo or redo the newest command; `a20.nothing-to-undo` and
//                                          `a20.nothing-to-redo` when the history cannot go that way.
// A refused action changes nothing.
//
// Digest ("a20.garden.v1"): the document only (tray, tone, each stroke's rake, capped flag and points, each stone, the
// next stone id). Snapshot schema 1: the garden document only, as its A20-P01 file (`GardenDocument.encoded()`); a
// stroke in progress, the rake style, the refusal and the undo history are not saved, and the undo history restarts
// after a restore (clarification Q5). The digest holds exactly what the snapshot holds because the engine refuses a
// restore whose digest differs from the saved one (`SnapshotError.stateMismatch`); the other fields are compared by
// `==`. Restoring a refused file throws its `DocumentRefusal`.
//
// Outcome: `strokes-<n>` with the number of strokes of the garden, or `refused-<code>` while the last stroke was
// refused (for example `refused-over-cap`). Quality: `level-0` (the full level: the relief with `vc_fbm` grain) and
// `level-1` (without grain), each one full-screen draw (clarification Q5).
//
// Feature 147 (A20-P03) T-A20-303 (FR-A20-301, FR-A20-303, FR-A20-304; clarification Q2; data-model.md "GardenCore
// additions"; contracts/stones.md "Commands", "Selection"; gaps G-STONES, G-SELECTION). Stones and the tool:
//   stone.place [kind 0…4, x 0…1, y 0…1]   places a stone of `GardenPalette.stones[kind]` (a whole index,
//                                          `a20.invalid-choice` otherwise) centred at (x, y) with rotation 0 and scale
//                                          1, as one `GardenHistory` command, and selects it. At
//                                          `GardenDocument.maxStones` stones it is refused with `a20.stone-cap` (the
//                                          controls say "The garden holds 24 stones.").
//   stone.select [id 0…4,294,967,295]      selects the stone with that id, or none for 0; an id that no stone has, or
//                                          that is not whole, is refused with `a20.unknown-stone`.
//   stone.move [x 0…1, y 0…1]              moves the selected stone's centre to (x, y), clamped inside the tray.
//   stone.rotate [angle −π…π]              turns the selected stone to `angle` (radians; positive turns its x axis
//                                          towards the tray's +y, clockwise on the screen).
//   stone.remove []                        removes the selected stone; the selection clears.
//   tool.mode [0…1]                        the canvas tool, a whole index: 0 rake, 1 stones (`a20.invalid-choice`).
// A move or rotate that names the stone's current value is accepted without a command. Move, rotate and remove without a
// selection are refused with `a20.no-selection`. Each changing stone action is one command, so `edit.undo` and
// `edit.redo` cover it. The selection and the tool are state, not document: they are compared by `==` but are not in
// the digest or the snapshot (a restore opens with no selection and the rake). The selection clears when its stone
// leaves the garden (removal, an undo of its placement, a redo of its removal, a restore or a reset).
import Foundation
import DigitalZenGardenCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence

/// The rule codes of Digital Zen Garden's refusals (feature 146).
public enum GardenRule {
    /// A value that is not a whole index of its choices.
    public static let invalidChoice = "a20.invalid-choice"
    /// `stroke.add` or `stroke.end` without a stroke in progress.
    public static let noStroke = "a20.no-stroke"
    /// `edit.undo` with nothing to undo.
    public static let nothingToUndo = "a20.nothing-to-undo"
    /// `edit.redo` with nothing to redo.
    public static let nothingToRedo = "a20.nothing-to-redo"
    /// `stone.move`, `stone.rotate` or `stone.remove` without a selected stone (feature 147).
    public static let noSelection = "a20.no-selection"
    /// `stone.select` with an id that no stone of the garden has (feature 147).
    public static let unknownStone = "a20.unknown-stone"
    /// `stone.place` while the garden holds `GardenDocument.maxStones` stones (feature 147).
    public static let stoneCap = "a20.stone-cap"
    /// The rule code of a history refusal: `a20.<code>` of the ``DocumentRefusal``.
    public static func refusal(_ refusal: DocumentRefusal) -> String { "a20." + refusal.code }
}

/// Clamping a position inside the tray (feature 147).
enum TrayClamp {
    /// (x, y) clamped into 0…1 on both axes; a value that is not finite becomes 0.5.
    static func clamped(_ x: Double, _ y: Double) -> Vec2 {
        func clamp(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0.5 }
        return Vec2(clamp(x), clamp(y))
    }
}

/// The state of Digital Zen Garden (see the file header). Snapshot schema 1.
public struct GardenCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a20.digital-zen-garden"
    /// The action ids in declaration order.
    public static let actionIDs = ["stroke.begin", "stroke.add", "stroke.end", "rake.style", "sand.tone",
                                   "edit.undo", "edit.redo", "stone.place", "stone.select", "stone.move",
                                   "stone.rotate", "stone.remove", "tool.mode"]
    /// The actions a canvas drag sends.
    public static let strokeActionIDs: Set<String> = ["stroke.begin", "stroke.add", "stroke.end"]
    /// The actions a canvas gesture of the stone tool sends: a tap selects, a drag moves, two fingers turn (feature
    /// 147).
    public static let stoneGestureActionIDs: Set<String> = ["stone.select", "stone.move", "stone.rotate"]
    /// The sentence the controls show when a stone is refused because the garden holds its most stones (feature 147).
    public static let stoneCapMessage = "The garden holds \(GardenDocument.maxStones) stones."
    /// The canvas tool of index 0: raking.
    public static let rakeTool = 0
    /// The canvas tool of index 1: stones.
    public static let stoneTool = 1
    /// The snapshot schema this build writes.
    public static let schemaVersion = 1
    /// The digest's domain string (schema 1).
    public static let digestDomain = "a20.garden.v1"
    /// The most raw points a stroke in progress keeps.
    public static let maxRawPoints = 2048
    /// The number of points one `stroke.add` carries.
    public static let pointsPerAdd = 12
    /// The prefix of the outcome code `strokes-<n>`.
    public static let strokesCodePrefix = "strokes-"
    /// The prefix of the outcome code `refused-<code>`.
    public static let refusedCodePrefix = "refused-"

    /// The command history; its ``GardenHistory/document`` is the garden.
    public private(set) var history: GardenHistory
    /// The raw points of the stroke in progress, in normalized tray coordinates (at most ``maxRawPoints``); empty
    /// when there is none.
    public private(set) var inProgress: [Vec2] = []
    /// The rake index (0 fine, 1 wide) of the stroke in progress; nil when no stroke is in progress.
    public private(set) var inProgressRake: Int?
    /// The rake of the next stroke: 0 fine, 1 wide (default 0).
    public private(set) var rakeStyle = 0
    /// The refusal code of the last stroke the history refused (for example `over-cap`); nil otherwise.
    public private(set) var lastRefusal: String?
    /// The canvas tool: ``rakeTool`` (0, the default) or ``stoneTool`` (1). State, not in the digest (feature 147).
    public private(set) var toolMode = 0
    /// The id of the selected stone; nil when none is. State, not in the digest (feature 147).
    public private(set) var selectedStone: UInt32?
    /// The quality tier the host set (0 = level-0, 1 = level-1, clamped); presentation only — not in the digest,
    /// the snapshot or `==`.
    public private(set) var qualityTier = 0

    /// The opening state: the empty garden, no stroke in progress, the fine rake.
    public init() {
        history = GardenHistory()
    }

    /// A state holding `document` with an empty undo history (the restore of a saved garden).
    public init(document: GardenDocument) {
        history = GardenHistory(document: document)
    }

    // MARK: Derived

    /// The garden.
    public var document: GardenDocument { history.document }

    /// Whether a stroke is in progress.
    public var isRaking: Bool { inProgressRake != nil }

    /// The rake style of index `index` (clamped to the two styles).
    public static func rake(index: Int) -> GardenPalette.RakeStyle {
        GardenPalette.rakes[min(max(index, 0), GardenPalette.rakes.count - 1)]
    }

    /// The index of the garden's sand tone in `GardenPalette.tones` (0 when unknown).
    public var toneIndex: Int { GardenPalette.tones.firstIndex { $0.id == document.tone } ?? 0 }

    /// The stroke in progress as it would be committed now: its raw points resampled with `StrokeResampler` and its
    /// rake; nil without a stroke in progress.
    public var pendingStroke: RakeStroke? {
        guard let rake = inProgressRake, !inProgress.isEmpty,
              case let .success(out) = StrokeResampler.resample(inProgress) else { return nil }
        return RakeStroke(rake: Self.rake(index: rake).id, points: out.points, capped: out.capped)
    }

    /// Whether the garden holds as many strokes as it may (`GardenDocument.maxStrokes`).
    public var isAtStrokeCap: Bool { document.strokes.count >= GardenDocument.maxStrokes }

    // MARK: Quality

    /// Two quality tiers: level-0 and level-1.
    public static var qualityTiers: Int { 2 }

    /// `level-0` (the relief without grain) and `level-1` (the relief with grain); each level is one full-screen
    /// draw at the full resolution, so both declare the full budgets.
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "level-0", resolutionShare: 1, iterationShare: 1),
                      QualityLevel(name: "level-1", resolutionShare: 1, iterationShare: 1)]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: every stored value except the presentation-only `qualityTier`.
    public static func == (lhs: GardenCore, rhs: GardenCore) -> Bool {
        lhs.history == rhs.history && lhs.inProgress == rhs.inProgress && lhs.inProgressRake == rhs.inProgressRake
            && lhs.rakeStyle == rhs.rakeStyle && lhs.lastRefusal == rhs.lastRefusal && lhs.toolMode == rhs.toolMode
            && lhs.selectedStone == rhs.selectedStone
    }

    /// The selected stone of the garden; nil without a selection (feature 147).
    public var selected: Stone? {
        guard let selectedStone else { return nil }
        return document.stones.first { $0.id == selectedStone }
    }

    /// Whether the garden holds as many stones as it may (`GardenDocument.maxStones`; feature 147).
    public var isAtStoneCap: Bool { document.stones.count >= GardenDocument.maxStones }

    /// Clears the selection when its stone is no longer in the garden.
    private mutating func dropMissingSelection() {
        if let selectedStone, !document.stones.contains(where: { $0.id == selectedStone }) {
            self.selectedStone = nil
        }
    }

    // MARK: Contract

    /// Schema 1, the first version: no migration steps.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: schemaVersion) }

    /// The declared controls, built once.
    private static let declaredControls: [ExperienceControl] = [
        ExperienceControl(id: "stroke.begin", ranges: [0...1, 0...1, 0...Double(GardenPalette.rakes.count - 1)]),
        ExperienceControl(id: "stroke.add",
                          ranges: [ClosedRange<Double>](repeating: 0...1, count: pointsPerAdd * 2)),
        ExperienceControl(id: "stroke.end", ranges: []),
        ExperienceControl(id: "rake.style", ranges: [0...Double(GardenPalette.rakes.count - 1)]),
        ExperienceControl(id: "sand.tone", ranges: [0...Double(GardenPalette.tones.count - 1)]),
        ExperienceControl(id: "edit.undo", ranges: []),
        ExperienceControl(id: "edit.redo", ranges: []),
        ExperienceControl(id: "stone.place", ranges: [0...Double(GardenPalette.stones.count - 1), 0...1, 0...1]),
        ExperienceControl(id: "stone.select", ranges: [0...Double(UInt32.max)]),
        ExperienceControl(id: "stone.move", ranges: [0...1, 0...1]),
        ExperienceControl(id: "stone.rotate", ranges: [-Double.pi...Double.pi]),
        ExperienceControl(id: "stone.remove", ranges: []),
        ExperienceControl(id: "tool.mode", ranges: [0...1]),
    ]

    /// The thirteen controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] { declaredControls }

    /// The opening state; nothing depends on the seed and no clock is read.
    public static func prepare(seed: UInt64) async throws -> GardenCore {
        try Task.checkCancellation()
        return GardenCore()
    }

    /// A host step changes nothing: nothing in the garden moves on its own.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if let refusal = ExperienceInput.validate(control: action.control, values: action.values,
                                                  controls: Self.declaredControls) {
            return .rejected(refusal)
        }
        let v = action.values
        let invalid = ActionResult.rejected(.rule(code: GardenRule.invalidChoice))
        switch action.control {
        case "stroke.begin":
            guard let rake = Self.choice(v[2], count: GardenPalette.rakes.count) else { return invalid }
            inProgress = [Vec2(v[0], v[1])]
            inProgressRake = rake
            lastRefusal = nil
        case "stroke.add":
            guard isRaking else { return .rejected(.rule(code: GardenRule.noStroke)) }
            for pair in 0..<Self.pointsPerAdd where inProgress.count < Self.maxRawPoints {
                let point = Vec2(v[pair * 2], v[pair * 2 + 1])
                if let last = inProgress.last,
                   StrokeResampler.trayDistance(last, point) < StrokeResampler.repeatDistance { continue }
                inProgress.append(point)
            }
        case "stroke.end":
            guard let rake = inProgressRake else { return .rejected(.rule(code: GardenRule.noStroke)) }
            let points = inProgress
            inProgress = []
            inProgressRake = nil
            switch history.rake(points, rake: Self.rake(index: rake).id) {
            case .success:
                lastRefusal = nil
            case let .failure(refusal):
                lastRefusal = refusal.code
            }
        case "rake.style":
            guard let rake = Self.choice(v[0], count: GardenPalette.rakes.count) else { return invalid }
            rakeStyle = rake
            lastRefusal = nil
        case "sand.tone":
            guard let index = Self.choice(v[0], count: GardenPalette.tones.count) else { return invalid }
            let tone = GardenPalette.tones[index].id
            if tone != document.tone {
                var next = history
                if case let .failure(refusal) = next.setTone(tone) {
                    return .rejected(.rule(code: GardenRule.refusal(refusal)))
                }
                history = next
            }
            lastRefusal = nil
        case "edit.undo":
            guard history.canUndo else { return .rejected(.rule(code: GardenRule.nothingToUndo)) }
            history.undo()
            dropMissingSelection()
            lastRefusal = nil
        case "edit.redo":
            guard history.canRedo else { return .rejected(.rule(code: GardenRule.nothingToRedo)) }
            history.redo()
            dropMissingSelection()
            lastRefusal = nil
        default:
            return applyStone(action.control, v)
        }
        return .accepted
    }

    /// Carries out a stone or tool action whose values the declared ranges accepted (feature 147; see the file
    /// header); a refused action changes nothing.
    private mutating func applyStone(_ control: String, _ v: [Double]) -> ActionResult {
        let invalid = ActionResult.rejected(.rule(code: GardenRule.invalidChoice))
        let noSelection = ActionResult.rejected(.rule(code: GardenRule.noSelection))
        switch control {
        case "stone.place":
            guard let kind = Self.choice(v[0], count: GardenPalette.stones.count) else { return invalid }
            guard !isAtStoneCap else { return .rejected(.rule(code: GardenRule.stoneCap)) }
            var next = history
            switch next.placeStone(kind: GardenPalette.stones[kind].id, position: TrayClamp.clamped(v[1], v[2])) {
            case let .success(stone):
                history = next
                selectedStone = stone.id
            case let .failure(refusal):
                return .rejected(.rule(code: GardenRule.refusal(refusal)))
            }
        case "stone.select":
            let value = v[0]
            guard value == value.rounded() else { return .rejected(.rule(code: GardenRule.unknownStone)) }
            let id = UInt32(value)
            if id == 0 {
                selectedStone = nil
            } else {
                guard document.stones.contains(where: { $0.id == id }) else {
                    return .rejected(.rule(code: GardenRule.unknownStone))
                }
                selectedStone = id
            }
        case "stone.move":
            guard let stone = selected else { return noSelection }
            let target = TrayClamp.clamped(v[0], v[1])
            if target != stone.position {
                var next = history
                if case let .failure(refusal) = next.moveStone(id: stone.id, to: target) {
                    return .rejected(.rule(code: GardenRule.refusal(refusal)))
                }
                history = next
            }
        case "stone.rotate":
            guard let stone = selected else { return noSelection }
            if v[0] != stone.rotation {
                var next = history
                if case let .failure(refusal) = next.rotateStone(id: stone.id, to: v[0]) {
                    return .rejected(.rule(code: GardenRule.refusal(refusal)))
                }
                history = next
            }
        case "stone.remove":
            guard let stone = selected else { return noSelection }
            var next = history
            if case let .failure(refusal) = next.removeStone(id: stone.id) {
                return .rejected(.rule(code: GardenRule.refusal(refusal)))
            }
            history = next
            selectedStone = nil
        default:   // tool.mode
            guard let tool = Self.choice(v[0], count: 2) else { return invalid }
            toolMode = tool
        }
        lastRefusal = nil
        return .accepted
    }

    /// The index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// Back to the opening state; the quality tier, which is not state, is kept.
    public mutating func reset() {
        let tier = qualityTier
        self = GardenCore()
        qualityTier = tier
    }

    /// `refused-<code>` while the last stroke was refused, else `strokes-<n>` with the garden's stroke count.
    public var outcome: ExperienceOutcome? {
        if let lastRefusal { return ExperienceOutcome(code: Self.refusedCodePrefix + lastRefusal) }
        return ExperienceOutcome(code: Self.strokesCodePrefix + String(document.strokes.count))
    }

    /// "a20.garden.v1", then the document: tray, tone, the strokes (rake, capped flag, points), the stones and the
    /// next stone id (see the file header).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        let garden = document
        builder.add(Self.digestDomain)
        builder.add(garden.tray)
        builder.add(garden.tone)
        builder.add(garden.strokes.count)
        for stroke in garden.strokes {
            builder.add(stroke.rake)
            builder.add(stroke.capped)
            builder.add(stroke.points.count)
            for point in stroke.points {
                try builder.add(point.x)
                try builder.add(point.y)
            }
        }
        builder.add(garden.stones.count)
        for stone in garden.stones {
            builder.add(UInt64(stone.id))
            builder.add(stone.kind)
            try builder.add(stone.position.x)
            try builder.add(stone.position.y)
            try builder.add(stone.rotation)
            try builder.add(stone.scale)
            builder.add(stone.depth)
        }
        builder.add(UInt64(garden.nextStoneID))
    }

    // MARK: Snapshot

    /// The garden document as its A20-P01 file (`GardenDocument.encoded()`: sorted keys, kind `a20.garden`).
    public func snapshotPayload() throws -> Data {
        try document.encoded()
    }

    /// The core holding the garden of `payload` with an empty undo history; a refused file throws its
    /// `DocumentRefusal`. The seed changes nothing.
    public static func restore(payload: Data, seed: UInt64) throws -> GardenCore {
        switch GardenDocument.decode(payload) {
        case let .success(document):
            return GardenCore(document: document)
        case let .failure(refusal):
            throw refusal
        }
    }
}
