// AuroraLoomGolden — feature 308 (R02-G01-08) T-R02G0108-002 (FR-R02G0108-003, 004; clarification Q3; research R2, R3;
// contracts/api.md). The code-only visual baseline of Aurora Loom: a fixed golden set of 16 frames (certified levels 1,
// 21, 41, 61 and 81 at host tiers 0, 1 and 2 at frame time 0, plus the hero frame: level 1 after the hero scenario's one
// move, tier 0) and, for each, the description of what the frame must show at the frame-check size 96 × 64 — the
// projected ribbon centre-line samples (32 segments per ribbon, as the feature-303 frame check uses them), the gate
// marker pixels with whether each marker is lit and the colour it must show, the night background colour and the tier's
// detail (layers, segments, glow passes). Positions are rounded to 1/8 pixel and colours to 8 bits, the whole serialized
// as JSON with sorted keys and hashed with SHA-256. Nothing is drawn here: the description is computed from the same CPU
// reference the renderer is checked against, so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned one
// and everything else is equal (the system's sine and cosine may differ in the last bit between macOS releases);
// otherwise it names the first differing value. Debug and automation builds only, like the scenarios.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Aurora Loom (see the file header).
public enum AuroraLoomGolden {
    /// One golden frame: a certified level, a host tier, a frame time and the moves applied from the opening play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`AuroraLoomTier.of`).
        public let tier: Int
        /// The frame time in ticks.
        public let time: Double
        /// The moves applied to the level's opening play before the frame.
        public let moves: [AuroraLoomMove]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, moves: [AuroraLoomMove]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.moves = moves
        }
    }

    /// The frame-check width in pixels.
    public static let width = 96
    /// The frame-check height in pixels.
    public static let height = 64
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The ribbon segments of the description (33 samples per ribbon).
    public static let segments = 32
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

    /// The hero scenario's move: ribbon 0's wave set to the first step that leaves level 1 unsolved (the first entry of
    /// `AuroraLoomExperienceCore.inputEntries`).
    static func heroMoves() -> [AuroraLoomMove] {
        guard let level = try? AuroraLoomExperienceCore.level(number: 1),
              let wave = AuroraLoomExperienceCore.losingStep(level.startSteps, level: level, ribbon: 0,
                                                              control: .wave) else { return [] }
        return [AuroraLoomMove(ribbon: 0, control: .wave, step: wave)]
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's moves applied, at its time.
    ///
    /// - Throws: the kernel's refusal of the level or of a move.
    public static func snapshot(_ frame: Frame) throws -> AuroraLoomSceneSnapshot {
        let level = try AuroraLoomExperienceCore.level(number: frame.level)
        var play = try AuroraLoomExperienceCore.freshPlay(of: level)
        for move in frame.moves { try play.apply(move, expecting: play.fingerprint) }
        return AuroraLoomSceneSnapshot(play: play, time: frame.time)
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

    /// A gate marker: its pixel, whether it is lit and the colour it must show.
    struct Marker: Codable, Equatable {
        let gate: Int
        let position: Position?
        let lit: Bool
        let colour: Colour
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let layers: Int
        let segments: Int
        let glowPasses: Int
        let width: Int
        let height: Int
        let quantum: Int
        let night: Colour
        let ribbonColours: [Colour]
        let ribbons: [[Position]]
        let markers: [Marker]
    }

    /// `c` in 8 bits per channel, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> Colour {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return Colour(r: byte(c.x), g: byte(c.y), b: byte(c.z))
    }

    /// `p` in 1/``quantum`` pixel.
    static func position(_ p: (x: Double, y: Double)) -> Position {
        Position(x: Int((p.x * Double(quantum)).rounded()), y: Int((p.y * Double(quantum)).rounded()))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot = try snapshot(frame)
        let tier = AuroraLoomTier.of(frame.tier)
        let aspect = Double(width) / Double(height)
        let samples = AuroraLoomSceneGeometry.referenceSamples(snapshot: snapshot, aspect: aspect, width: width,
                                                               height: height, segments: segments)
        var ribbons: [[Position]] = []
        for line in samples { ribbons.append(line.map { position($0) }) }
        var markers: [Marker] = []
        for gate in 0..<4 {
            var lit = true
            for ribbon in 0..<3 where !snapshot.lit(ribbon: ribbon, gate: gate) { lit = false }
            let pixel = AuroraLoomSceneGeometry.markerPixel(gate: gate, snapshot: snapshot, aspect: aspect, width: width,
                                                            height: height)
            markers.append(Marker(gate: gate, position: pixel.map { position($0) }, lit: lit,
                                  colour: colour(AuroraLoomShaders.gateColour(AuroraLoomPalette.gold, lit: lit))))
        }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, layers: tier.layers,
                           segments: tier.segments, glowPasses: tier.glowPasses, width: width, height: height,
                           quantum: quantum, night: colour(AuroraLoomPalette.night),
                           ribbonColours: AuroraLoomPalette.ribbons.map { colour($0) }, ribbons: ribbons,
                           markers: markers)
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

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be the
    /// digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position lies
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
        // The pinned digest must be the digest of the pinned description, so a hand-edited entry cannot pass.
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
        if a.layers != b.layers || a.segments != b.segments || a.glowPasses != b.glowPasses {
            return "\(frame): tier detail differs (pinned \(b.layers) layers, \(b.segments) segments, \(b.glowPasses) glow)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.night != b.night { return "\(frame): night colour differs" }
        if a.ribbonColours != b.ribbonColours { return "\(frame): ribbon colours differ" }
        if a.ribbons.count != b.ribbons.count { return "\(frame): ribbon count differs" }
        for r in 0..<a.ribbons.count {
            if a.ribbons[r].count != b.ribbons[r].count { return "\(frame): ribbon \(r) sample count differs" }
            for i in 0..<a.ribbons[r].count where !near(a.ribbons[r][i], b.ribbons[r][i]) {
                let p = a.ribbons[r][i], q = b.ribbons[r][i]
                return "\(frame): ribbon \(r) sample \(i) at (\(p.x), \(p.y)) eighths, pinned (\(q.x), \(q.y))"
            }
        }
        if a.markers.count != b.markers.count { return "\(frame): marker count differs" }
        for g in 0..<a.markers.count {
            let m = a.markers[g], n = b.markers[g]
            if m.gate != n.gate || m.lit != n.lit || m.colour != n.colour {
                return "\(frame): marker \(g) state or colour differs"
            }
            switch (m.position, n.position) {
            case (nil, nil): continue
            case let (p?, q?) where near(p, q): continue
            default: return "\(frame): marker \(g) position differs"
            }
        }
        return nil
    }

    /// Whether two positions lie within one quantum on each axis.
    static func near(_ p: Position, _ q: Position) -> Bool { abs(p.x - q.x) <= 1 && abs(p.y - q.y) <= 1 }
}
#endif
