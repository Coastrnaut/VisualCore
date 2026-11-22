// AmethystEscapeGolden — feature 368 (R02-G07-08) T-R02G0708-003 (FR-R02G0708-003, 004; clarification Q3;
// research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Amethyst Escape: a fixed
// golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0, each
// after its witness's first min(smallest − 1, 3) actions, so the move bar and turned shells show while the pearl is
// still inside; plus the hero frame: level 1 after the hero scenario's first turn, tier 0) and, for each, the
// description of what the frame must show at the frame-check size 1,152 × 768 with the authored camera: the pearl
// centre, the exit arrow centre and every wedge top centre (shell by shell, own sector ascending, each marked open or
// blocked), the backdrop, amethyst, highlight, platinum, blocked, pearl, exit and amber colours, the move count, the
// move bar's length and the tier's detail (bevel segments, highlight layers, glow shells). Positions are rounded to
// 1/8 pixel (an off-screen point is null), the move bar's length to 1/1,024 and colours to 8-bit sRGB, the whole
// serialized as JSON with sorted keys and hashed with SHA-256. Nothing is drawn here: the description is computed from
// the same CPU reference the renderer is checked against (feature 363), so it is a baseline made by code, never a
// stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one, the move bar's length within one 1/1,024 quantum, and everything else is equal (the system's trigonometry may
// differ in the last bit between macOS releases); otherwise it names the first differing value. A pinned digest must
// equal the digest of its pinned description, so a hand-edited entry cannot pass. Debug and automation builds only,
// like the scenarios; the Release symbol check forbids this type. Modelled on `ChronoConstellatorGolden` (feature 358).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Amethyst Escape (see the file header).
public enum AmethystEscapeGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`AmethystEscapeTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [AmethystEscapeAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [AmethystEscapeAction]) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
        }
    }

    /// The frame-check width in pixels (the feature-363 frame-check size).
    public static let width = 1_152
    /// The frame-check height in pixels.
    public static let height = 768
    /// The schema of the pinned file.
    public static let schema = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum = 8
    /// The move bar's length is stored in units of 1/`lengthQuantum`.
    public static let lengthQuantum = 1_024
    /// The levels of the golden set, one per band.
    public static let levels: [Int] = [1, 21, 41, 61, 81]
    /// At most this many witness actions are applied, and always fewer than the witness's whole escape.
    public static let moves = 3

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (level 1 after the
    /// hero scenario's first turn, ``AmethystEscapeExperienceCore/inputActions`` [0], tier 0). A level that cannot be
    /// generated has no actions (``AmethystEscapeExperienceCore/certifiedActions(_:)`` is empty), which its comparison
    /// then reports.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [AmethystEscapeAction] = witnessPrefix(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: 0,
                                  actions: actions))
            }
        }
        let hero: [AmethystEscapeAction] = Array(AmethystEscapeExperienceCore.inputActions.prefix(1))
        list.append(Frame(name: "hero", level: 1, tier: 0, time: 0, actions: hero))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The first min(smallest − 1, ``moves``) actions of `level`'s certified escape, so the pearl has not escaped.
    static func witnessPrefix(level: Int) -> [AmethystEscapeAction] {
        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(level)
        return Array(actions.prefix(max(0, min(actions.count - 1, moves))))
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at its time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> AmethystEscapeSceneSnapshot {
        let level: AmethystEscapeLevel = try AmethystEscapeExperienceCore.level(number: frame.level)
        var play: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return AmethystEscapeSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
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

    /// A projected wedge top: its shell, its own sector, whether it is open (not a blocked wedge) and its pixel (nil
    /// off screen or behind the camera).
    struct Wedge: Codable, Equatable {
        let shell: Int
        let sector: Int
        let open: Bool
        let position: Position?
    }

    /// The description of one frame (see the file header).
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let moves: Int
        let moveBar: Int
        let bevelSegments: Int
        let highlightLayers: Int
        let glowShells: Int
        let width: Int
        let height: Int
        let quantum: Int
        let backdrop: Colour
        let amethyst: Colour
        let highlight: Colour
        let platinum: Colour
        let blocked: Colour
        let pearlColour: Colour
        let exitColour: Colour
        let amber: Colour
        let pearl: Position?
        let exit: Position?
        let wedges: [Wedge]
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
        let snapshot: AmethystEscapeSceneSnapshot = try snapshot(frame)
        let tier: AmethystEscapeTier = AmethystEscapeTier.of(frame.tier)
        let geometry = AmethystEscapeSceneGeometry.self
        let camera: AmethystEscapeCamera = geometry.camera(snapshot, aspect: Double(width) / Double(height))
        func project(_ p: SIMD3<Double>) -> Position? {
            position(geometry.pixel(p, camera: camera, width: width, height: height))
        }
        var wedges: [Wedge] = []
        for (shell, entry) in snapshot.shells.enumerated() {
            for sector in 0..<snapshot.sectors {
                let top: SIMD3<Double> = geometry.wedgeTopCentre(shell: shell, sector: sector, snapshot)
                wedges.append(Wedge(shell: shell, sector: sector, open: !entry.blocked.contains(sector),
                                    position: project(top)))
            }
        }
        let palette = AmethystEscapePalette.self
        let length: Double = geometry.moveBarLength(snapshot)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, moves: snapshot.moves,
                           moveBar: Int((length * Double(lengthQuantum)).rounded()),
                           bevelSegments: tier.bevelSegments, highlightLayers: tier.highlightLayers,
                           glowShells: tier.glowShells, width: width, height: height, quantum: quantum,
                           backdrop: colour(palette.backdrop), amethyst: colour(palette.amethyst),
                           highlight: colour(palette.highlight), platinum: colour(palette.platinum),
                           blocked: colour(palette.blocked), pearlColour: colour(palette.pearl),
                           exitColour: colour(palette.exit), amber: colour(palette.amber),
                           pearl: project(geometry.pearlCentre(snapshot)), exit: project(geometry.exitCentre(snapshot)),
                           wedges: wedges)
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
        guard manifest.schema == schema else {
            return "golden-frames.json has schema \(manifest.schema), not \(schema)"
        }
        guard let entry = manifest.frames[frame.name] else { return "golden-frames.json has no frame \(frame.name)" }
        guard StableHash.sha256Hex(Array(try encoder.encode(entry.description))) == entry.digest else {
            return "golden-frames.json entry \(frame.name): the digest does not match its description"
        }
        let current: Description = try describe(frame)
        if StableHash.sha256Hex(Array(try encoder.encode(current))) == entry.digest { return nil }
        return difference(current, entry.description)
    }

    /// The first difference between `a` (recomputed) and `b` (pinned) beyond one quantum of position or length, or nil.
    static func difference(_ a: Description, _ b: Description) -> String? {
        let frame = a.name
        if a.name != b.name || a.level != b.level || a.tier != b.tier {
            return "\(frame): identity differs (\(b.name) level \(b.level) tier \(b.tier) pinned)"
        }
        if a.moves != b.moves { return "\(frame): moves \(a.moves), pinned \(b.moves)" }
        if abs(a.moveBar - b.moveBar) > 1 {
            return "\(frame): move bar \(a.moveBar)/\(lengthQuantum), pinned \(b.moveBar)"
        }
        if a.bevelSegments != b.bevelSegments || a.highlightLayers != b.highlightLayers
            || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.bevelSegments) bevel segments, \(b.highlightLayers) "
                + "highlight layers, \(b.glowShells) glow shells)"
        }
        if a.width != b.width || a.height != b.height || a.quantum != b.quantum { return "\(frame): size differs" }
        if a.backdrop != b.backdrop || a.amethyst != b.amethyst || a.highlight != b.highlight
            || a.platinum != b.platinum || a.blocked != b.blocked || a.pearlColour != b.pearlColour
            || a.exitColour != b.exitColour || a.amber != b.amber {
            return "\(frame): palette colour differs"
        }
        if !near(a.pearl, b.pearl) {
            return "\(frame): pearl centre at \(text(a.pearl)) eighths, pinned \(text(b.pearl))"
        }
        if !near(a.exit, b.exit) { return "\(frame): exit arrow at \(text(a.exit)) eighths, pinned \(text(b.exit))" }
        if a.wedges.count != b.wedges.count { return "\(frame): wedge count differs" }
        for (m, n) in zip(a.wedges, b.wedges) {
            if m.shell != n.shell || m.sector != n.sector || m.open != n.open {
                return "\(frame): wedge \(m.shell).\(m.sector) differs (pinned \(n.shell).\(n.sector), open \(n.open))"
            }
            if !near(m.position, n.position) {
                return "\(frame): wedge top \(m.shell).\(m.sector) at \(text(m.position)) eighths, pinned "
                    + text(n.position)
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
