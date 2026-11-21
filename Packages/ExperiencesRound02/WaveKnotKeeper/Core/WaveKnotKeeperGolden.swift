// WaveKnotKeeperGolden — feature 328 (R02-G03-08) T-R02G0308-003 (FR-R02G0308-003, 004; clarification Q3; research
// R2, R3, R5; contracts/api.md). The code-only visual baseline of Wave Knot Keeper: a fixed golden set of 16 frames
// (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0, plus the hero frame: level 1
// after the hero scenario's one move, tier 0) and, for each, the description of what the frame must show at the
// frame-check size 1,152 × 768 with the authored camera — the projected control points (each also a handle centre,
// pearl with no selection), the segment midpoints, the gate centres and the drawn crossing points with their
// over-strands, the night, pearl, sapphire and ember colours and the tier's detail (tube sides, corner samples, glow
// shells). Positions are rounded to 1/8 pixel and colours to 8 bits, the whole serialized as JSON with sorted keys and
// hashed with SHA-256. Nothing is drawn here: the description is computed from the same CPU reference the renderer is
// checked against (feature 323), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned one
// and everything else is equal (the system's trigonometry may differ in the last bit between macOS releases); otherwise
// it names the first differing value. A pinned digest must equal the digest of its pinned description, so a hand-edited
// entry cannot pass. Debug and automation builds only, like the scenarios; the Release symbol check forbids this type.
// Modelled on `LissajousLabyrinthGolden` (feature 318).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Wave Knot Keeper (see the file header).
public enum WaveKnotKeeperGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the moves applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`WaveKnotKeeperTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The moves applied to the level's opening play before the frame.
        public let moves: [WaveKnotKeeperMove]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, moves: [WaveKnotKeeperMove]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.moves = moves
        }
    }

    /// The frame-check width in pixels (the feature-323 frame-check size).
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: 0, moves: []))
            }
        }
        list.append(Frame(name: "hero", level: 1, tier: 0, time: 0, moves: heroMoves()))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The hero scenario's move: the first input move of the manifest's opening level (`heroEntries`).
    static func heroMoves() -> [WaveKnotKeeperMove] {
        Array(WaveKnotKeeperExperienceCore.inputMoves.prefix(1))
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's moves applied, at its time, with no
    /// selection.
    ///
    /// - Throws: the kernel's refusal of the level or of a move.
    public static func snapshot(_ frame: Frame) throws -> WaveKnotKeeperSceneSnapshot {
        let level = try WaveKnotKeeperExperienceCore.level(number: frame.level)
        var play = try WaveKnotKeeperExperienceCore.freshPlay(of: level)
        for move in frame.moves { try play.apply(move, expecting: play.fingerprint) }
        return WaveKnotKeeperSceneSnapshot(play: play, levelNumber: frame.level, selected: nil, time: frame.time)
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

    /// A drawn crossing: its two segments, its over-strand and its pixel.
    struct Crossing: Codable, Equatable {
        let first: Int
        let second: Int
        let over: Int
        let position: Position?
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let sides: Int
        let cornerSamples: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let pearl: Colour
        let sapphire: Colour
        let ember: Colour
        let points: [Position?]
        let midpoints: [Position?]
        let gates: [Position?]
        let crossings: [Crossing]
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
        let snapshot = try snapshot(frame)
        let tier = WaveKnotKeeperTier.of(frame.tier)
        let geometry = WaveKnotKeeperSceneGeometry.self
        let camera = geometry.camera(for: snapshot, aspect: Double(width) / Double(height))
        func project(_ p: SIMD3<Double>) -> Position? {
            position(geometry.pixel(p, camera: camera, width: width, height: height))
        }
        let points: [Position?] = geometry.worldPoints(snapshot).map { project($0) }
        let midpoints: [Position?] = geometry.segmentMidpoints(snapshot).map { project($0) }
        let gates: [Position?] = snapshot.gates.map { project(geometry.gateCentre($0)) }
        var crossings: [Crossing] = []
        for mark in snapshot.crossings {
            crossings.append(Crossing(first: mark.first, second: mark.second, over: mark.over,
                                      position: geometry.drawnCrossingPoint(mark, in: snapshot).flatMap { project($0) }))
        }
        let shaders = WaveKnotKeeperShaders.self
        return Description(name: frame.name, level: frame.level, tier: frame.tier, sides: tier.sides,
                           cornerSamples: tier.cornerSamples, glowShells: tier.glowShells, width: width,
                           height: height, quantum: quantum, night: colour(WaveKnotKeeperPalette.night),
                           pearl: colour(shaders.solidColour(WaveKnotKeeperPalette.pearl)),
                           sapphire: colour(shaders.solidColour(WaveKnotKeeperPalette.sapphire)),
                           ember: colour(shaders.solidColour(WaveKnotKeeperPalette.ember)), points: points,
                           midpoints: midpoints, gates: gates, crossings: crossings)
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// The description of `frame` as JSON with sorted keys.
    ///
    /// - Throws: the kernel's refusal of the level or of a move; an encoding failure.
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
        if a.sides != b.sides || a.cornerSamples != b.cornerSamples || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.sides) sides, \(b.cornerSamples) corner samples, "
                + "\(b.glowShells) glow shells)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.night != b.night || a.pearl != b.pearl || a.sapphire != b.sapphire || a.ember != b.ember {
            return "\(frame): palette colour differs"
        }
        if let message = positions("point", a.points, b.points, frame: frame) { return message }
        if let message = positions("midpoint", a.midpoints, b.midpoints, frame: frame) { return message }
        if let message = positions("gate", a.gates, b.gates, frame: frame) { return message }
        if a.crossings.count != b.crossings.count { return "\(frame): crossing count differs" }
        for (m, n) in zip(a.crossings, b.crossings) {
            if m.first != n.first || m.second != n.second || m.over != n.over {
                return "\(frame): crossing \(m.first)/\(m.second) differs"
            }
            if !near(m.position, n.position) { return "\(frame): crossing \(m.first)/\(m.second) position differs" }
        }
        return nil
    }

    /// The first `kind` position of `a` farther than one quantum from `b`'s, or a count difference, in words; nil when
    /// none.
    static func positions(_ kind: String, _ a: [Position?], _ b: [Position?], frame: String) -> String? {
        if a.count != b.count { return "\(frame): \(kind) count differs" }
        for i in 0..<a.count where !near(a[i], b[i]) {
            return "\(frame): \(kind) \(i) at \(text(a[i])) eighths, pinned \(text(b[i]))"
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
