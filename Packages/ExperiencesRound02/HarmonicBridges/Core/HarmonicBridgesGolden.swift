// HarmonicBridgesGolden — feature 418 (R02-G12-08) T-R02G1208-003 (FR-R02G1208-003, 004; SC-R02G1208-003; clarification
// Q3; research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Harmonic Bridges: a
// fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0,
// each after its witness's tunings and before its test, so bridges, filled marks, pips and spent gauge bars show while
// the level is not won (a won level lifts its bridges); plus the hero frame: the manifest seed's level after the hero
// scenario's actions (the certified tunings of level 1 without the test), tier 0) and, for each, the description of what
// the frame must show at the frame-check size 1,152 × 768 with the authored camera: every island top (island order),
// every string midpoint (string order), the membrane check point of every bridge of the shown step (string order), every
// step pip (index order) and the gauge's first bar, the counts of islands, strings, bridges in the shown step, filled and
// hollow marks, pips and lit and total gauge bars, the shown step, the tier's detail (string motion, wave shells, glow
// shells) and the ground, island face, island edge, string, membrane, filled mark, hollow mark, start, goal, pip, unlit
// pip, lit gauge and unlit gauge colours. Positions are rounded to 1/8 pixel (a point that does not project, or projects
// outside the frame, is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with
// SHA-256 (`StableHash`). Nothing is drawn here: the description is computed from the same snapshot and scene geometry
// the renderer draws (feature 413; the marks filled exactly where `HarmonicBridgesSceneGeometry.isFilled` says, as
// the bridge mesh draws them), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. Debug and automation builds
// only, like the scenarios; the Release symbol check forbids this type. Modelled on `EchoCartographerGolden`
// (feature 408).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Harmonic Bridges (see the file header).
public enum HarmonicBridgesGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`HarmonicBridgesTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [HarmonicBridgesAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [HarmonicBridgesAction]) {
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
    /// The presentation time of every frame: 0, so the shown step is step 0 (the string wave and the wave shells are
    /// shader work; no described position depends on the time).
    public static let time = 0.0
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "ground", "islandFace", "islandEdge", "string", "membrane", "markFilled", "markHollow", "start", "goal", "pip",
        "pipUnlit", "gaugeLit", "gaugeUnlit",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (the manifest seed's
    /// level after the hero scenario's actions, the certified tunings without the test
    /// (``HarmonicBridgesExperienceCore/certifiedTunings(_:)``), tier 0). A level that cannot be generated has no
    /// actions.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [HarmonicBridgesAction] = frameActions(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let heroLevel: Int = HarmonicBridgesExperienceCore.levelNumber(
            forSeed: HarmonicBridgesExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time,
                          actions: HarmonicBridgesExperienceCore.certifiedTunings(heroLevel)))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The certified witness of `level` without its final test: every action but the last (the plan's tunings).
    static func frameActions(level: Int) -> [HarmonicBridgesAction] {
        let certified: [HarmonicBridgesAction] = HarmonicBridgesExperienceCore.certifiedActions(level)
        return Array(certified.dropLast())
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at the frame's
    /// time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> HarmonicBridgesSceneSnapshot {
        let level: HarmonicBridgesLevel = try HarmonicBridgesExperienceCore.level(number: frame.level)
        var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return HarmonicBridgesSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        let islands: Int
        let strings: Int
        let bridges: Int
        let filledMarks: Int
        let hollowMarks: Int
        let pips: Int
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
        let step: Int
        let motion: Bool
        let waveShells: Int
        let glowShells: Int
        let counts: Counts
        let colours: [String: Colour]
        let islandTops: [[Int]?]
        let stringMidpoints: [[Int]?]
        let membranes: [[Int]?]
        let pips: [[Int]?]
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
            try c.encode(step, forKey: .step)
            try c.encode(motion, forKey: .motion)
            try c.encode(waveShells, forKey: .waveShells)
            try c.encode(glowShells, forKey: .glowShells)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(islandTops, forKey: .islandTops)
            try c.encode(stringMidpoints, forKey: .stringMidpoints)
            try c.encode(membranes, forKey: .membranes)
            try c.encode(pips, forKey: .pips)
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
        case "ground": return HarmonicBridgesPalette.ground
        case "islandFace": return HarmonicBridgesPalette.islandFace
        case "islandEdge": return HarmonicBridgesPalette.islandEdge
        case "string": return HarmonicBridgesPalette.string
        case "membrane": return HarmonicBridgesPalette.membrane
        case "markFilled": return HarmonicBridgesPalette.markFilled
        case "markHollow": return HarmonicBridgesPalette.markHollow
        case "start": return HarmonicBridgesPalette.start
        case "goal": return HarmonicBridgesPalette.goal
        case "pip": return HarmonicBridgesPalette.pip
        case "pipUnlit": return HarmonicBridgesPalette.pipUnlit
        case "gaugeLit": return HarmonicBridgesPalette.gaugeLit
        default: return HarmonicBridgesPalette.gaugeUnlit
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project or lies outside the
    /// frame.
    static func position(_ point: SIMD3<Double>, camera: HarmonicBridgesCamera) -> [Int]? {
        guard let p = HarmonicBridgesSceneGeometry.project(point, camera: camera),
              p.x >= 0, p.x <= 1, p.y >= 0, p.y <= 1 else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: HarmonicBridgesCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: HarmonicBridgesSceneSnapshot = try snapshot(frame)
        let tier: HarmonicBridgesTier = HarmonicBridgesTier.of(frame.tier)
        let camera: HarmonicBridgesCamera = HarmonicBridgesSceneGeometry.camera(snapshot,
                                                                            aspect: Double(width) / Double(height))
        let step: Int = HarmonicBridgesSceneGeometry.drawnStep(snapshot, reduceMotion: false)
        var islandPoints: [SIMD3<Double>] = []
        for index in snapshot.islands.indices {
            islandPoints.append(HarmonicBridgesSceneGeometry.islandTop(index, snapshot))
        }
        var stringPoints: [SIMD3<Double>] = []
        var membranePoints: [SIMD3<Double>] = []
        var filled: Int = 0
        var hollow: Int = 0
        for index in snapshot.strings.indices {
            stringPoints.append(HarmonicBridgesSceneGeometry.stringMidpoint(index, snapshot))
            if snapshot.isBridge(index, step: step) {
                membranePoints.append(HarmonicBridgesSceneGeometry.membraneMidpoint(index, snapshot))
            }
            for k in 1...HarmonicBridgesSwing.samples {
                if HarmonicBridgesSceneGeometry.isFilled(index, sample: k, step: step, snapshot) {
                    filled += 1
                } else {
                    hollow += 1
                }
            }
        }
        var pipPoints: [SIMD3<Double>] = []
        for index in 0..<snapshot.steps { pipPoints.append(HarmonicBridgesSceneGeometry.stepPip(index, snapshot)) }
        let gaugeTotal: Int = max(snapshot.budget, 0)
        let firstGaugeBar: [Int]? = gaugeTotal > 0
            ? position(HarmonicBridgesSceneGeometry.gaugeBar(0, snapshot), camera: camera) : nil
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(islands: snapshot.islands.count, strings: snapshot.strings.count,
                                    bridges: membranePoints.count, filledMarks: filled, hollowMarks: hollow,
                                    pips: snapshot.steps, gaugeLit: HarmonicBridgesSceneGeometry.litBars(snapshot),
                                    gaugeTotal: gaugeTotal)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, step: step, motion: tier.motion, waveShells: tier.waveShells,
                           glowShells: tier.glowShells, counts: counts, colours: colours,
                           islandTops: positions(islandPoints, camera: camera),
                           stringMidpoints: positions(stringPoints, camera: camera),
                           membranes: positions(membranePoints, camera: camera),
                           pips: positions(pipPoints, camera: camera),
                           firstGaugeBar: firstGaugeBar)
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
        if a.step != b.step { return "\(frame): shown step \(a.step), pinned \(b.step)" }
        if a.motion != b.motion || a.waveShells != b.waveShells || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs"
        }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if let found = firstFar("island top", a.islandTops, b.islandTops) { return "\(frame): " + found }
        if let found = firstFar("string midpoint", a.stringMidpoints, b.stringMidpoints) { return "\(frame): " + found }
        if let found = firstFar("membrane", a.membranes, b.membranes) { return "\(frame): " + found }
        if let found = firstFar("pip", a.pips, b.pips) { return "\(frame): " + found }
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
