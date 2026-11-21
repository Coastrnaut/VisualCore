// LissajousLabyrinthGolden — feature 318 (R02-G02-08) T-R02G0208-003 (FR-R02G0208-003, 004; clarification Q3; research
// R2, R3, R5; contracts/api.md). The code-only visual baseline of Lissajous Labyrinth: a fixed golden set of 16 frames
// (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0, plus the hero frame: level 1
// after the hero scenario's one action, tier 0) and, for each, the description of what the frame must show at the
// frame-check size 1,152 × 768 with the authored camera — the projected path samples the frame check uses (every 32nd
// lap tick at the tier's stride), each checkpoint ring's band point with its state and the colour it must show, each
// obstacle's centre with whether the lap touches it and its colour, each dial ring's centre and knob, the night
// background and the tier's detail (samples, glow passes, trail). Positions are rounded to 1/8 pixel and colours to 8
// bits, the whole serialized as JSON with sorted keys and hashed with SHA-256. Nothing is drawn here: the description is
// computed from the same CPU reference the renderer is checked against, so it is a baseline made by code, never a
// stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned one
// and everything else is equal (the system's sine and cosine may differ in the last bit between macOS releases);
// otherwise it names the first differing value. A pinned digest must equal the digest of its pinned description, so a
// hand-edited entry cannot pass. Debug and automation builds only, like the scenarios; the Release symbol check forbids
// this type. Modelled on `AuroraLoomGolden` (feature 308).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Lissajous Labyrinth (see the file header).
public enum LissajousLabyrinthGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`LissajousLabyrinthTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The actions applied to the level's opening play before the frame.
        public let actions: [LissajousLabyrinthAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [LissajousLabyrinthAction]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
        }
    }

    /// The frame-check width in pixels (12 × the 96 × 64 still, feature 314).
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The lap ticks between checked path samples (128 samples per lap at every tier).
    public static let tickStep = 32
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: 0, actions: []))
            }
        }
        list.append(Frame(name: "hero", level: 1, tier: 0, time: 0, actions: heroActions()))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The hero scenario's action: phase A set to the first value that leaves level 1 unsolved (the first entry of
    /// `LissajousLabyrinthExperienceCore.inputEntries`).
    static func heroActions() -> [LissajousLabyrinthAction] {
        guard let level = try? LissajousLabyrinthExperienceCore.level(number: 1),
              let phaseA = LissajousLabyrinthExperienceCore.losingPhase(level.start, level: level) else { return [] }
        return [LissajousLabyrinthAction(dial: .phaseA, value: phaseA)]
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at its time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> LissajousLabyrinthSceneSnapshot {
        let level = try LissajousLabyrinthExperienceCore.level(number: frame.level)
        var play = try LissajousLabyrinthExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return LissajousLabyrinthSceneSnapshot(play: play, time: frame.time)
    }

    /// A position in 1/``quantum`` pixel.
    struct Position: Codable, Equatable {
        let x: Int
        let y: Int
    }

    /// An 8-bit colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// A checkpoint ring: its band point's pixel, its state and the colour it must show.
    struct Ring: Codable, Equatable {
        let index: Int
        let position: Position?
        let state: String
        let colour: Colour
    }

    /// An obstacle: its centre's pixel, whether the lap touches it and its base colour.
    struct Obstacle: Codable, Equatable {
        let index: Int
        let position: Position?
        let touched: Bool
        let colour: Colour
    }

    /// A dial ring: its centre's and its knob's pixels at the dial's value.
    struct Dial: Codable, Equatable {
        let dial: String
        let value: Int
        let centre: Position?
        let knob: Position?
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let samples: Int
        let glowPasses: Int
        let trail: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let path: [Position?]
        let rings: [Ring]
        let obstacles: [Obstacle]
        let dials: [Dial]
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

    /// The state colour of checkpoint `index`: lit copper when visited, the mean of dim and lit when it is the next one,
    /// dim copper otherwise (as the feature-313 frame check).
    static func ringColour(_ snapshot: LissajousLabyrinthSceneSnapshot, index: Int) -> (String, SIMD3<Double>) {
        let dim = LissajousLabyrinthShaders.solidColour(LissajousLabyrinthPalette.copper, lit: false)
        let lit = LissajousLabyrinthShaders.solidColour(LissajousLabyrinthPalette.copper, lit: true)
        if snapshot.visited(index) { return ("visited", lit) }
        if snapshot.nextCheckpoint == index { return ("next", dim + (lit - dim) * 0.5) }
        return ("unvisited", dim)
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot = try snapshot(frame)
        let tier = LissajousLabyrinthTier.of(frame.tier)
        let geometry = LissajousLabyrinthSceneGeometry.self
        let vp = geometry.viewProjection(aspect: Double(width) / Double(height), snapshot: snapshot)
        func project(_ p: Vec3) -> Position? {
            position(geometry.project(p, viewProjection: vp, width: width, height: height))
        }
        var path: [Position?] = []
        let points = geometry.path(snapshot, tier: tier)
        let step = max(tickStep / max(tier.stride, 1), 1)
        var j = 0
        while j < points.count {
            path.append(project(points[j]))
            j += step
        }
        var rings: [Ring] = []
        for (index, ball) in snapshot.level.checkpoints.enumerated() {
            let state = ringColour(snapshot, index: index)
            rings.append(Ring(index: index, position: project(geometry.ringBandPoint(ball)), state: state.0,
                              colour: colour(state.1)))
        }
        var obstacles: [Obstacle] = []
        for (index, ball) in snapshot.level.obstacles.enumerated() {
            let touched = snapshot.contactObstacle == index
            let base = touched ? LissajousLabyrinthPalette.copper : LissajousLabyrinthPalette.violet
            obstacles.append(Obstacle(index: index, position: project(geometry.world(ball)), touched: touched,
                                      colour: colour(LissajousLabyrinthShaders.solidColour(base, lit: touched))))
        }
        var dials: [Dial] = []
        for dial in LissajousLabyrinthDial.allCases {
            let value = snapshot.dials[dial]
            dials.append(Dial(dial: dial.rawValue, value: value,
                              centre: project(LissajousLabyrinthHandles.ringCentre(dial, level: snapshot.level)),
                              knob: project(LissajousLabyrinthHandles.knob(dial, value: value, level: snapshot.level))))
        }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, samples: tier.samples,
                           glowPasses: tier.glowPasses, trail: tier.trail, width: width, height: height,
                           quantum: quantum, night: colour(LissajousLabyrinthPalette.night), path: path, rings: rings,
                           obstacles: obstacles, dials: dials)
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
            let described = try describe(frame)
            entries[frame.name] = Entry(description: described,
                                        digest: StableHash.sha256Hex(Array(try encoder.encode(described))))
        }
        return try encoder.encode(Manifest(schema: schema, frames: entries))
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position lies
    /// within one quantum of the pinned one and everything else is equal; otherwise the first difference in words,
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
        let current = try describe(frame)
        if StableHash.sha256Hex(Array(try encoder.encode(current))) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.samples != b.samples || a.glowPasses != b.glowPasses || a.trail != b.trail {
            return "\(frame): tier detail differs (pinned \(b.samples) samples, \(b.glowPasses) glow, \(b.trail) trail)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.night != b.night { return "\(frame): night colour differs" }
        if a.path.count != b.path.count { return "\(frame): path sample count differs" }
        for i in 0..<a.path.count where !near(a.path[i], b.path[i]) {
            return "\(frame): path sample \(i) at \(text(a.path[i])) eighths, pinned \(text(b.path[i]))"
        }
        if a.rings.count != b.rings.count { return "\(frame): ring count differs" }
        for (m, n) in zip(a.rings, b.rings) {
            if m.index != n.index || m.state != n.state || m.colour != n.colour {
                return "\(frame): ring \(m.index) state or colour differs"
            }
            if !near(m.position, n.position) { return "\(frame): ring \(m.index) position differs" }
        }
        if a.obstacles.count != b.obstacles.count { return "\(frame): obstacle count differs" }
        for (m, n) in zip(a.obstacles, b.obstacles) {
            if m.index != n.index || m.touched != n.touched || m.colour != n.colour {
                return "\(frame): obstacle \(m.index) state or colour differs"
            }
            if !near(m.position, n.position) { return "\(frame): obstacle \(m.index) position differs" }
        }
        if a.dials.count != b.dials.count { return "\(frame): dial count differs" }
        for (m, n) in zip(a.dials, b.dials) {
            if m.dial != n.dial || m.value != n.value { return "\(frame): dial \(m.dial) value differs" }
            if !near(m.centre, n.centre) || !near(m.knob, n.knob) { return "\(frame): dial \(m.dial) position differs" }
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
