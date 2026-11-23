// EchoCartographerGolden — feature 408 (R02-G11-08) T-R02G1108-003 (FR-R02G1108-003, 004; SC-R02G1108-003; clarification
// Q3; research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Echo Cartographer: a
// fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0,
// each after its witness's first min(pulses − 1, 2) pulses (at least one) and one marker on the first known-open cell
// that is not the entry, so walls, rays, a marker ring and spent gauge bars show while the level is not won; plus the
// hero frame: the manifest seed's level after the hero scenario's actions, tier 0) and, for each, the description of
// what the frame must show at the frame-check size 1,152 × 768 with the authored camera: every known floor tile's
// centre, every known wall's top-face centre, every marker ring centre and every located beacon pillar's top in cell
// order, the entry and the first gauge bar, the counts of known open cells, known walls, markers, located beacons, rays
// and lit and total gauge bars, the tier's detail (rings, flare trails, glow shells) and the ground, floor, entry,
// marker, wall face, wall edge, pillar, ray, gauge lit and gauge unlit colours. Positions are rounded to 1/8 pixel (an
// off-screen point is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with
// SHA-256 (`StableHash`). Nothing is drawn here: the description is computed from the same snapshot and scene geometry
// the renderer draws (feature 403), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. Debug and automation builds
// only, like the scenarios; the Release symbol check forbids this type. Modelled on `BackwardsAuroraGolden`
// (feature 398).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Echo Cartographer (see the file header).
public enum EchoCartographerGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`EchoCartographerTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [EchoCartographerAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [EchoCartographerAction]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
        }
    }

    /// The frame-check width in pixels.
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]
    /// At most this many certified pulses are applied (at least one, and claims never: the level is not won).
    public static let pulses = 2
    /// The presentation time of every frame: 0 (the rings and flares are shader uniforms; no position depends on the
    /// time).
    public static let time = 0.0
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "ground", "floor", "entry", "marker", "wallFace", "wallEdge", "pillar", "ray", "gaugeLit", "gaugeUnlit",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (the manifest seed's
    /// level after the hero scenario's actions, ``EchoCartographerExperienceCore/inputActions``, tier 0). A level that
    /// cannot be generated has no actions.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [EchoCartographerAction] = frameActions(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let heroLevel: Int = EchoCartographerExperienceCore.levelNumber(
            forSeed: EchoCartographerExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time,
                          actions: EchoCartographerExperienceCore.inputActions))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The first min(pulses − 1, ``pulses``) pulses (at least one) of `level`'s certified witness, then one marker on
    /// the first cell (cell-index order) known open after them that is not the entry (none when there is none).
    static func frameActions(level: Int) -> [EchoCartographerAction] {
        let certified: [EchoCartographerAction] = EchoCartographerExperienceCore.certifiedActions(level)
        var pulsesOnly: [EchoCartographerAction] = []
        for action in certified {
            if case .pulse = action { pulsesOnly.append(action) }
        }
        let count: Int = max(1, min(pulsesOnly.count - 1, pulses))
        var actions: [EchoCartographerAction] = Array(pulsesOnly.prefix(count))
        guard let level = try? EchoCartographerExperienceCore.level(number: level),
              var play = try? EchoCartographerExperienceCore.freshPlay(of: level) else { return actions }
        for action in actions { try? play.apply(action, expecting: play.fingerprint) }
        let chamber: EchoCartographerChamber = level.chamber
        for index in 0..<chamber.cellCount {
            let cell: EchoCartographerCell = chamber.cell(index)
            if play.knowledge[index] == .open && cell != level.entry {
                actions.append(.mark(cell.x, cell.y))
                break
            }
        }
        return actions
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at the frame's
    /// time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> EchoCartographerSceneSnapshot {
        let level: EchoCartographerLevel = try EchoCartographerExperienceCore.level(number: frame.level)
        var play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return EchoCartographerSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        let open: Int
        let walls: Int
        let markers: Int
        let located: Int
        let rays: Int
        let gaugeLit: Int
        let gaugeTotal: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null.
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let rings: Bool
        let flareTrails: Bool
        let glowShells: Int
        let counts: Counts
        let colours: [String: Colour]
        let floors: [[Int]?]
        let walls: [[Int]?]
        let markers: [[Int]?]
        let pillars: [[Int]?]
        let entry: [Int]?
        let firstGaugeBar: [Int]?

        /// Encodes every field; a missing position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(rings, forKey: .rings)
            try c.encode(flareTrails, forKey: .flareTrails)
            try c.encode(glowShells, forKey: .glowShells)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(floors, forKey: .floors)
            try c.encode(walls, forKey: .walls)
            try c.encode(markers, forKey: .markers)
            try c.encode(pillars, forKey: .pillars)
            try c.encode(entry, forKey: .entry)
            try c.encode(firstGaugeBar, forKey: .firstGaugeBar)
        }
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// One channel 0 … 1 as a byte.
    static func byte(_ v: Double) -> Int {
        Int((min(max(v, 0), 1) * 255).rounded())
    }

    /// The palette colour named `name` (one of ``colourNames``).
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        switch name {
        case "ground": return EchoCartographerPalette.ground
        case "floor": return EchoCartographerPalette.floor
        case "entry": return EchoCartographerPalette.entry
        case "marker": return EchoCartographerPalette.marker
        case "wallFace": return EchoCartographerPalette.wallFace
        case "wallEdge": return EchoCartographerPalette.wallEdge
        case "pillar": return EchoCartographerPalette.pillar
        case "ray": return EchoCartographerPalette.pulse
        case "gaugeLit": return EchoCartographerPalette.gaugeLit
        default: return EchoCartographerPalette.gaugeUnlit
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project.
    static func position(_ point: SIMD3<Double>, camera: EchoCartographerCamera) -> [Int]? {
        guard let p = EchoCartographerSceneGeometry.project(point, camera: camera) else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: EchoCartographerCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: EchoCartographerSceneSnapshot = try snapshot(frame)
        let tier: EchoCartographerTier = EchoCartographerTier.of(frame.tier)
        let camera: EchoCartographerCamera = EchoCartographerSceneGeometry.camera(snapshot,
                                                                              aspect: Double(width) / Double(height))
        let reference: EchoCartographerReferencePoints = EchoCartographerSceneGeometry.referencePoints(snapshot)
        var pillarPoints: [SIMD3<Double>] = []
        for cell in snapshot.located { pillarPoints.append(EchoCartographerSceneGeometry.pillarTop(cell, snapshot)) }
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(open: snapshot.openCells.count, walls: snapshot.wallCells.count,
                                    markers: snapshot.markers.count, located: snapshot.located.count,
                                    rays: snapshot.lastEcho?.rays.count ?? 0,
                                    gaugeLit: EchoCartographerSceneGeometry.litBars(snapshot),
                                    gaugeTotal: max(snapshot.budget, 0))
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, rings: tier.rings, flareTrails: tier.flareTrails,
                           glowShells: tier.glowShells, counts: counts, colours: colours,
                           floors: positions(reference.floors, camera: camera),
                           walls: positions(reference.walls, camera: camera),
                           markers: positions(reference.markers, camera: camera),
                           pillars: positions(pillarPoints, camera: camera),
                           entry: position(reference.entry, camera: camera),
                           firstGaugeBar: position(reference.firstGaugeBar, camera: camera))
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e: JSONEncoder = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// The SHA-256 hex of a description as the pinned file encodes it.
    static func hash(_ description: Description) throws -> String {
        StableHash.sha256Hex(Array(try encoder.encode(description)))
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
            entries[frame.name] = Entry(description: described, digest: try hash(described))
        }
        return try encoder.encode(Manifest(schema: schema, frames: entries))
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position
    /// lies within one quantum of the pinned one and every colour and count is equal; otherwise the first difference in
    /// words, naming the frame.
    ///
    /// - Throws: as ``description(_:)``.
    public static func compare(_ frame: Frame, pinned: Data) throws -> String? {
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: pinned) else {
            return "golden-frames.json is unreadable"
        }
        guard manifest.schema == schema else {
            return "golden-frames.json has schema \(manifest.schema), not \(schema)"
        }
        guard let entry = manifest.frames[frame.name] else { return "golden-frames.json has no frame \(frame.name)" }
        guard try hash(entry.description) == entry.digest else {
            return "golden-frames.json entry \(frame.name): the digest does not match its description"
        }
        let current: Description = try describe(frame)
        if try hash(current) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame: String = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.rings != b.rings || a.flareTrails != b.flareTrails || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs"
        }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if let found = firstFar("floor", a.floors, b.floors) { return "\(frame): " + found }
        if let found = firstFar("wall", a.walls, b.walls) { return "\(frame): " + found }
        if let found = firstFar("marker", a.markers, b.markers) { return "\(frame): " + found }
        if let found = firstFar("pillar", a.pillars, b.pillars) { return "\(frame): " + found }
        if !near(a.entry, b.entry) { return "\(frame): entry at \(text(a.entry)) eighths, pinned \(text(b.entry))" }
        if !near(a.firstGaugeBar, b.firstGaugeBar) {
            return "\(frame): first gauge bar at \(text(a.firstGaugeBar)) eighths, pinned \(text(b.firstGaugeBar))"
        }
        return nil
    }

    /// The first position of `a` farther than one quantum from `b`'s, in words, or nil.
    static func firstFar(_ what: String, _ a: [[Int]?], _ b: [[Int]?]) -> String? {
        if a.count != b.count { return "\(a.count) \(what) points, pinned \(b.count)" }
        for index in a.indices where !near(a[index], b[index]) {
            return "\(what) \(index) at \(text(a[index])) eighths, pinned " + text(b[index])
        }
        return nil
    }

    /// Whether two positions lie within one quantum on each axis (both nil also counts).
    static func near(_ p: [Int]?, _ q: [Int]?) -> Bool {
        guard let p, let q else { return p == nil && q == nil }
        guard p.count == 2, q.count == 2 else { return false }
        return abs(p[0] - q[0]) <= 1 && abs(p[1] - q[1]) <= 1
    }

    /// A position in words for messages.
    static func text(_ p: [Int]?) -> String {
        guard let p, p.count == 2 else { return "none" }
        return "(\(p[0]), \(p[1]))"
    }
}
#endif
