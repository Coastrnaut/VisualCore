// ColorfallCanyonsGolden — feature 348 (R02-G05-08) T-R02G0508-003 (FR-R02G0508-003, 004; clarification Q3; research R2,
// R3, R5; data-model.md; contracts/api.md). The code-only visual baseline of Colorfall Canyons: a fixed golden set of 16
// frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0, each after its
// witness's edits — its carves and valves, never its steps — followed by `step(12)` so fluid shows, plus the hero frame:
// level 1 after the hero scenario's one time step, tier 0) and, for each, the description of what the frame must show at
// the frame-check size 1,152 × 768 with the authored camera — every cell's block top centre, every spring emitter's top
// centre, every basin centre and every wet cell's fluid sheet top centre (the cell centre at the sheet top's height)
// with that cell's fluid mix, the night, sandstone, rock, pearl, cyan, coral and yellow colours, the play tick and the
// tier's detail (block subdivision, flow bands, glow shells). Positions are rounded to 1/8 pixel and colours to 8-bit
// sRGB, the whole serialized as JSON with sorted keys and hashed with SHA-256. Nothing is drawn here: the description is
// computed from the same CPU reference the renderer is checked against (feature 343), so it is a baseline made by code,
// never a stored picture.
//
// A wet cell's colour is `ColorfallCanyonsPalette.fluid(masses)`, the mass-weighted mix of the three fluid colours, not
// the brightness-scaled `ColorfallCanyonsSceneGeometry.fluidColour`: the brightness is a function of the volume alone,
// which the sheet top's height already pins, and the unscaled mix is the hue the simulator frame check compares (the
// rendered brightness also carries the flow-band shading, which varies with the tier).
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned one
// and everything else is equal (the system's trigonometry may differ in the last bit between macOS releases); otherwise
// it names the first differing value. A pinned digest must equal the digest of its pinned description, so a hand-edited
// entry cannot pass. Debug and automation builds only, like the scenarios; the Release symbol check forbids this type.
// Modelled on `HueCompassGolden` (feature 338).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Colorfall Canyons (see the file header).
public enum ColorfallCanyonsGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`ColorfallCanyonsTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [ColorfallCanyonsAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [ColorfallCanyonsAction]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
        }
    }

    /// The frame-check width in pixels (the feature-343 frame-check size).
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]
    /// The ticks run after the witness's edits, so the fluid shows.
    public static let ticks = 12

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (level 1 after the
    /// hero scenario's one time step, ``ColorfallCanyonsExperienceCore/inputSteps`` [0] ticks, tier 0). A level that
    /// cannot be generated has no edits (``ColorfallCanyonsExperienceCore/certifiedActions(_:)`` is empty), which its
    /// comparison then reports.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [ColorfallCanyonsAction] = witnessEdits(level: level) + [.step(ticks)]
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: 0,
                                  actions: actions))
            }
        }
        list.append(Frame(name: "hero", level: 1, tier: 0, time: 0,
                          actions: [.step(ColorfallCanyonsExperienceCore.inputSteps[0])]))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The certified witness edits of `level` (its carve and valve actions in solver order, without its steps).
    static func witnessEdits(level: Int) -> [ColorfallCanyonsAction] {
        ColorfallCanyonsExperienceCore.certifiedActions(level).filter { action in
            if case .step = action { return false }
            return true
        }
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at its time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> ColorfallCanyonsSceneSnapshot {
        let level: ColorfallCanyonsLevel = try ColorfallCanyonsExperienceCore.level(number: frame.level)
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return ColorfallCanyonsSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// A position in 1/``quantum`` pixel.
    struct Position: Codable, Equatable {
        let x: Int
        let y: Int
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// A projected point of the scene: the index of its cell, spring or basin and its pixel (nil behind the camera).
    struct Point: Codable, Equatable {
        let index: Int
        let position: Position?
    }

    /// A wet cell's fluid sheet: its cell, the pixel of its top centre and its fluid mix.
    struct Sheet: Codable, Equatable {
        let cell: Int
        let position: Position?
        let colour: Colour
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let tick: Int
        let subdivision: Int
        let flowBands: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let sandstone: Colour
        let rock: Colour
        let pearl: Colour
        let cyan: Colour
        let coral: Colour
        let yellow: Colour
        let cells: [Point]
        let emitters: [Point]
        let basins: [Point]
        let sheets: [Sheet]
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// `p` in 1/``quantum`` pixel; nil stays nil.
    static func position(_ p: Vec2?) -> Position? {
        guard let p else { return nil }
        return Position(x: Int((p.x * Double(quantum)).rounded()), y: Int((p.y * Double(quantum)).rounded()))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: ColorfallCanyonsSceneSnapshot = try snapshot(frame)
        let tier: ColorfallCanyonsTier = ColorfallCanyonsTier.of(frame.tier)
        let geometry = ColorfallCanyonsSceneGeometry.self
        let camera: ColorfallCanyonsCamera = geometry.camera(snapshot, aspect: Double(width) / Double(height))
        func project(_ p: SIMD3<Double>) -> Position? {
            position(geometry.pixel(p, camera: camera, width: width, height: height))
        }
        var cells: [Point] = []
        var sheets: [Sheet] = []
        for cell in 0..<snapshot.cellCount {
            cells.append(Point(index: cell, position: project(geometry.cellTop(cell, snapshot))))
            if snapshot.volume(cell) > 0 {
                var top: SIMD3<Double> = geometry.cellCentre(cell, snapshot)
                top.y = geometry.sheetTop(cell, snapshot)
                sheets.append(Sheet(cell: cell, position: project(top),
                                    colour: colour(ColorfallCanyonsPalette.fluid(snapshot.masses[cell]))))
            }
        }
        var emitters: [Point] = []
        for spring in snapshot.springs.indices {
            emitters.append(Point(index: spring, position: project(geometry.emitterTop(spring, snapshot))))
        }
        var basins: [Point] = []
        for basin in snapshot.basins.indices {
            basins.append(Point(index: basin, position: project(geometry.basinCentre(basin, snapshot))))
        }
        let palette = ColorfallCanyonsPalette.self
        return Description(name: frame.name, level: frame.level, tier: frame.tier, tick: snapshot.tick,
                           subdivision: tier.subdivision, flowBands: tier.flowBands, glowShells: tier.glowShells,
                           width: width, height: height, quantum: quantum, night: colour(palette.night),
                           sandstone: colour(palette.sandstone), rock: colour(palette.rock),
                           pearl: colour(palette.pearl), cyan: colour(palette.cyan), coral: colour(palette.coral),
                           yellow: colour(palette.yellow), cells: cells, emitters: emitters, basins: basins,
                           sheets: sheets)
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// The description of `frame` as JSON with sorted keys.
    ///
    /// - Throws: the kernel's refusal of the level or of an action; an encoding failure.
    public static func description(_ frame: Frame) throws -> Data {
        try encoder.encode(describe(frame))
    }

    /// The SHA-256 hex of ``description(_:)``.
    ///
    /// - Throws: as ``description(_:)``.
    public static func digest(_ frame: Frame) throws -> String {
        StableHash.sha256Hex(Array(try description(frame)))
    }

    /// One pinned frame: its description and digest.
    struct Entry: Codable, Equatable {
        let description: Description
        let digest: String
    }

    /// The pinned file.
    struct Manifest: Codable, Equatable {
        let schema: Int
        let frames: [String: Entry]
    }

    /// The pinned file's content for the current code: `{"schema": 1, "frames": {name: {"description", "digest"}}}`,
    /// JSON with sorted keys, one entry per golden frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func manifest() throws -> Data {
        var entries: [String: Entry] = [:]
        for frame in frames {
            let described: Description = try describe(frame)
            entries[frame.name] = Entry(description: described,
                                        digest: StableHash.sha256Hex(Array(try encoder.encode(described))))
        }
        return try encoder.encode(Manifest(schema: schema, frames: entries))
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position
    /// lies within one quantum of the pinned one and everything else is equal; otherwise the first difference in words,
    /// naming the frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func compare(_ frame: Frame, pinned: Data) throws -> String? {
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: pinned) else {
            return "golden-frames.json is unreadable"
        }
        guard manifest.schema == schema else { return "golden-frames.json has schema \(manifest.schema), not \(schema)" }
        guard let entry = manifest.frames[frame.name] else { return "golden-frames.json has no frame \(frame.name)" }
        guard StableHash.sha256Hex(Array(try encoder.encode(entry.description))) == entry.digest else {
            return "golden-frames.json entry \(frame.name): the digest does not match its description"
        }
        let current: Description = try describe(frame)
        if StableHash.sha256Hex(Array(try encoder.encode(current))) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.tick != b.tick { return "\(frame): tick \(a.tick), pinned \(b.tick)" }
        if a.subdivision != b.subdivision || a.flowBands != b.flowBands || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned subdivision \(b.subdivision), \(b.flowBands) flow bands, "
                + "\(b.glowShells) glow shells)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.night != b.night || a.sandstone != b.sandstone || a.rock != b.rock || a.pearl != b.pearl
            || a.cyan != b.cyan || a.coral != b.coral || a.yellow != b.yellow {
            return "\(frame): palette colour differs"
        }
        if let message = points("cell top", a.cells, b.cells, frame: frame) { return message }
        if let message = points("emitter top", a.emitters, b.emitters, frame: frame) { return message }
        if let message = points("basin centre", a.basins, b.basins, frame: frame) { return message }
        if a.sheets.count != b.sheets.count { return "\(frame): wet cell count differs" }
        for (m, n) in zip(a.sheets, b.sheets) {
            if m.cell != n.cell { return "\(frame): wet cell \(m.cell), pinned \(n.cell)" }
            if m.colour != n.colour { return "\(frame): fluid colour of cell \(m.cell) differs" }
            if !near(m.position, n.position) {
                return "\(frame): sheet top \(m.cell) at \(text(m.position)) eighths, pinned \(text(n.position))"
            }
        }
        return nil
    }

    /// The first `kind` point of `a` that differs from `b`'s in index or beyond one quantum of position, or a count
    /// difference, in words; nil when none.
    static func points(_ kind: String, _ a: [Point], _ b: [Point], frame: String) -> String? {
        if a.count != b.count { return "\(frame): \(kind) count differs" }
        for (m, n) in zip(a, b) {
            if m.index != n.index { return "\(frame): \(kind) \(m.index), pinned \(n.index)" }
            if !near(m.position, n.position) {
                return "\(frame): \(kind) \(m.index) at \(text(m.position)) eighths, pinned \(text(n.position))"
            }
        }
        return nil
    }

    /// Whether two positions lie within one quantum on each axis (both nil also counts).
    static func near(_ p: Position?, _ q: Position?) -> Bool {
        switch (p, q) {
        case (nil, nil): return true
        case let (p?, q?): return abs(p.x - q.x) <= 1 && abs(p.y - q.y) <= 1
        default: return false
        }
    }

    /// A position in words for messages.
    static func text(_ p: Position?) -> String {
        guard let p else { return "none" }
        return "(\(p.x), \(p.y))"
    }
}
#endif
