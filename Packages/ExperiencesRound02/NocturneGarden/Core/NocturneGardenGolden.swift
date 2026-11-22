// NocturneGardenGolden — feature 388 (R02-G09-08) T-R02G0908-003 (FR-R02G0908-003, 004; SC-R02G0908-003; clarification
// Q3; research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Nocturne Garden: a
// fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0,
// each after its certified solution's first min(smallest − 1, 2) moves, so blooms, their shadow and spent gauge bars
// show while the level is not won; plus the hero frame: the manifest seed's level after the hero scenario's first move,
// tier 0) and, for each, the description of what the frame must show at the frame-check size 1,152 × 768 with the
// authored camera: every bloom head's centre in canonical bloom order (the mean of its outline at the head's middle
// depth) and the lantern's centre, the shadow cell count, the moves spent and the budget, the tier's detail (mist
// layers, stem depth, feather in 1/100 cell, glow shells) and the ground, mist, shadow, gold, coral, leak, lantern,
// spent and unspent colours. Positions are rounded to 1/8 pixel (an off-screen point is null) and colours to 8-bit
// sRGB, the whole serialized as JSON with sorted keys and hashed with SHA-256 (`StableHash`). Nothing is drawn here:
// the description is computed from the same snapshot and scene geometry the renderer draws (feature 383), so it is a
// baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal (the system's trigonometry may differ in the last bit between macOS
// releases); otherwise it names the frame and the first differing value. A pinned digest must equal the digest of its
// pinned description, so a hand-edited entry cannot pass. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `FacetedForgeGolden` (feature 378).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Nocturne Garden (see the file header).
public enum NocturneGardenGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the moves applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`NocturneGardenTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [NocturneGardenAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [NocturneGardenAction]) {
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
    /// At most this many certified moves are applied, and always fewer than the certified solution's whole length.
    public static let moves = 2
    /// The presentation time of every frame: 0 (the mist drift and the sway are shader uniforms; no position depends
    /// on the time).
    public static let time = 0.0
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "ground", "mist", "shadow", "gold", "coral", "leak", "lantern", "spent", "unspent",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (level 1 after the
    /// hero scenario's first move, ``NocturneGardenExperienceCore/inputActions`` [0], tier 0). A level that cannot be
    /// generated has no actions (``NocturneGardenExperienceCore/certifiedActions(_:)`` is empty).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [NocturneGardenAction] = certifiedPrefix(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let hero: [NocturneGardenAction] = Array(NocturneGardenExperienceCore.inputActions.prefix(1))
        let heroLevel: Int = NocturneGardenExperienceCore.levelNumber(
            forSeed: NocturneGardenExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: hero))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The first min(smallest − 1, ``moves``) moves of `level`'s certified solution, so the level is not won.
    static func certifiedPrefix(level: Int) -> [NocturneGardenAction] {
        let actions: [NocturneGardenAction] = NocturneGardenExperienceCore.certifiedActions(level)
        return Array(actions.prefix(max(0, min(actions.count - 1, moves))))
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at the frame's
    /// time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> NocturneGardenSceneSnapshot {
        let level: NocturneGardenLevel = try NocturneGardenExperienceCore.level(number: frame.level)
        var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return NocturneGardenSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null.
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let mistLayers: Int
        let stemDepth: Int
        let featherHundredths: Int
        let glowShells: Int
        let shadowCells: Int
        let moves: Int
        let budget: Int
        let colours: [String: Colour]
        let blooms: [[Int]?]
        let lantern: [Int]?

        /// Encodes every field; a missing lantern position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(mistLayers, forKey: .mistLayers)
            try c.encode(stemDepth, forKey: .stemDepth)
            try c.encode(featherHundredths, forKey: .featherHundredths)
            try c.encode(glowShells, forKey: .glowShells)
            try c.encode(shadowCells, forKey: .shadowCells)
            try c.encode(moves, forKey: .moves)
            try c.encode(budget, forKey: .budget)
            try c.encode(colours, forKey: .colours)
            try c.encode(blooms, forKey: .blooms)
            try c.encode(lantern, forKey: .lantern)
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
        case "ground": return NocturneGardenPalette.ground
        case "mist": return NocturneGardenPalette.mist
        case "shadow": return NocturneGardenPalette.shadow
        case "gold": return NocturneGardenPalette.gold
        case "coral": return NocturneGardenPalette.coral
        case "leak": return NocturneGardenPalette.leak
        case "lantern": return NocturneGardenPalette.lantern
        case "spent": return NocturneGardenPalette.spent
        default: return NocturneGardenPalette.unspent
        }
    }

    /// `p` in 1/``quantum`` pixel; nil stays nil.
    static func position(_ p: Vec2?) -> [Int]? {
        guard let p else { return nil }
        let x: Int = Int((p.x * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(quantum)).rounded())
        return [x, y]
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: NocturneGardenSceneSnapshot = try snapshot(frame)
        let tier: NocturneGardenTier = NocturneGardenTier.of(frame.tier)
        let camera: NocturneGardenCamera = NocturneGardenSceneGeometry.camera(snapshot,
                                                                          aspect: Double(width) / Double(height))
        var blooms: [[Int]?] = []
        for bloom in snapshot.blooms {
            blooms.append(position(NocturneGardenSceneGeometry.pixel(headCentre(bloom, snapshot), camera: camera,
                                                                     width: width, height: height)))
        }
        let lantern: [Int]? = position(NocturneGardenSceneGeometry.pixel(
            NocturneGardenSceneGeometry.lantern(snapshot), camera: camera, width: width, height: height))
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, mistLayers: tier.mistLayers, stemDepth: tier.stemDepth,
                           featherHundredths: Int((tier.feather * 100).rounded()), glowShells: tier.glowShells,
                           shadowCells: snapshot.shadow.count, moves: snapshot.moves, budget: snapshot.budget,
                           colours: colours, blooms: blooms, lantern: lantern)
    }

    /// The centre of `bloom`'s head: the mean of its outline at the head's middle depth (``NocturneGardenSceneGeometry/
    /// bloomZ`` plus half the ``NocturneGardenSceneGeometry/headDepth``).
    static func headCentre(_ bloom: NocturneGardenBloom, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let outline: [SIMD2<Double>] = NocturneGardenSceneGeometry.headOutline(bloom, snapshot)
        var sum: SIMD2<Double> = .zero
        for point in outline { sum += point }
        let mean: SIMD2<Double> = outline.isEmpty ? .zero : sum / Double(outline.count)
        let z: Double = NocturneGardenSceneGeometry.bloomZ + NocturneGardenSceneGeometry.headDepth / 2
        return SIMD3(mean.x, mean.y, z)
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
        if a.mistLayers != b.mistLayers || a.stemDepth != b.stemDepth || a.featherHundredths != b.featherHundredths
            || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.mistLayers) mist layers, stem depth \(b.stemDepth), "
                + "feather \(b.featherHundredths)/100, \(b.glowShells) glow shells)"
        }
        if a.shadowCells != b.shadowCells { return "\(frame): \(a.shadowCells) shadow cells, pinned \(b.shadowCells)" }
        if a.moves != b.moves { return "\(frame): moves \(a.moves), pinned \(b.moves)" }
        if a.budget != b.budget { return "\(frame): budget \(a.budget), pinned \(b.budget)" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if a.blooms.count != b.blooms.count {
            return "\(frame): \(a.blooms.count) blooms, pinned \(b.blooms.count)"
        }
        for index in a.blooms.indices where !near(a.blooms[index], b.blooms[index]) {
            return "\(frame): bloom \(index + 1) head centre at \(text(a.blooms[index])) eighths, pinned "
                + text(b.blooms[index])
        }
        if !near(a.lantern, b.lantern) {
            return "\(frame): lantern centre at \(text(a.lantern)) eighths, pinned \(text(b.lantern))"
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
