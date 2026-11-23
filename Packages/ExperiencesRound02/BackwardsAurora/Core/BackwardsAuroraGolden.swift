// BackwardsAuroraGolden — feature 398 (R02-G10-08) T-R02G1008-003 (FR-R02G1008-003, 004; SC-R02G1008-003; clarification
// Q3; research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Backwards Aurora: a
// fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 0,
// each after its certified solution's first min(smallest − 1, 2) reversals, so the reshaped wave, its kinks and spent
// gauge bars show while the level is not won; plus the hero frame: the manifest seed's level after the hero scenario's
// first reversal, tier 0) and, for each, the description of what the frame must show at the frame-check size
// 1,152 × 768 with the authored camera and the panel's opening section (samples 0 … 1): every sample point of the
// ribbon in wave order, every checkpoint ring centre in checkpoint order, the kink count, the tear seam (or none), the
// reversals spent and the budget, the tier's detail (trailing layers, pulses, glow shells) and the ground, band,
// ribbon, ghost, ring, matched, kink, tear, spent and unspent colours. Positions are rounded to 1/8 pixel (an off-screen
// point is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with SHA-256
// (`StableHash`). Nothing is drawn here: the description is computed from the same snapshot and scene geometry the
// renderer draws (feature 393), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal (the system's trigonometry may differ in the last bit between macOS
// releases); otherwise it names the frame and the first differing value. A pinned digest must equal the digest of its
// pinned description, so a hand-edited entry cannot pass. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `NocturneGardenGolden` (feature 388).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Backwards Aurora (see the file header).
public enum BackwardsAuroraGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the reversals applied from the
    /// opening play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`BackwardsAuroraTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [BackwardsAuroraAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [BackwardsAuroraAction]) {
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
    /// At most this many certified reversals are applied, and always fewer than the certified solution's whole length.
    public static let reversals = 2
    /// The presentation time of every frame: 0 (the shimmer and the pulses are shader uniforms; no position depends on
    /// the time).
    public static let time = 0.0
    /// The panel's opening section, as every frame shows it (samples 0 … 1).
    public static let section: ClosedRange<Int> = 0...1
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "ground", "band", "ribbon", "ghost", "ring", "matched", "kink", "tear", "spent", "unspent",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (the manifest seed's
    /// level after the hero scenario's first reversal, ``BackwardsAuroraExperienceCore/inputActions`` [0], tier 0). A
    /// level that cannot be generated has no actions (``BackwardsAuroraExperienceCore/certifiedActions(_:)`` is empty).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [BackwardsAuroraAction] = certifiedPrefix(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let hero: [BackwardsAuroraAction] = Array(BackwardsAuroraExperienceCore.inputActions.prefix(1))
        let heroLevel: Int = BackwardsAuroraExperienceCore.levelNumber(
            forSeed: BackwardsAuroraExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: hero))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The first min(smallest − 1, ``reversals``) reversals of `level`'s certified solution, so the level is not won.
    static func certifiedPrefix(level: Int) -> [BackwardsAuroraAction] {
        let actions: [BackwardsAuroraAction] = BackwardsAuroraExperienceCore.certifiedActions(level)
        return Array(actions.prefix(max(0, min(actions.count - 1, reversals))))
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at the frame's
    /// time, with the panel's opening section.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> BackwardsAuroraSceneSnapshot {
        let level: BackwardsAuroraLevel = try BackwardsAuroraExperienceCore.level(number: frame.level)
        var play: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return BackwardsAuroraSceneSnapshot(play: play, levelNumber: frame.level, sectionStart: section.lowerBound,
                                            sectionEnd: section.upperBound, time: frame.time)
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
        let trailingLayers: Int
        let pulses: Int
        let glowShells: Int
        let kinks: Int
        let tear: Int?
        let spent: Int
        let budget: Int
        let colours: [String: Colour]
        let samples: [[Int]?]
        let rings: [[Int]?]

        /// Encodes every field; a missing tear or position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(trailingLayers, forKey: .trailingLayers)
            try c.encode(pulses, forKey: .pulses)
            try c.encode(glowShells, forKey: .glowShells)
            try c.encode(kinks, forKey: .kinks)
            try c.encode(tear, forKey: .tear)
            try c.encode(spent, forKey: .spent)
            try c.encode(budget, forKey: .budget)
            try c.encode(colours, forKey: .colours)
            try c.encode(samples, forKey: .samples)
            try c.encode(rings, forKey: .rings)
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
        case "ground": return BackwardsAuroraPalette.ground
        case "band": return BackwardsAuroraPalette.band
        case "ribbon": return BackwardsAuroraPalette.ribbon
        case "ghost": return BackwardsAuroraPalette.ghost
        case "ring": return BackwardsAuroraPalette.ring
        case "matched": return BackwardsAuroraPalette.matched
        case "kink": return BackwardsAuroraPalette.kink
        case "tear": return BackwardsAuroraPalette.tear
        case "spent": return BackwardsAuroraPalette.spent
        default: return BackwardsAuroraPalette.unspent
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project.
    static func position(_ point: SIMD3<Double>, camera: BackwardsAuroraCamera) -> [Int]? {
        guard let p = BackwardsAuroraSceneGeometry.project(point, camera: camera) else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: BackwardsAuroraSceneSnapshot = try snapshot(frame)
        let tier: BackwardsAuroraTier = BackwardsAuroraTier.of(frame.tier)
        let camera: BackwardsAuroraCamera = BackwardsAuroraSceneGeometry.camera(snapshot,
                                                                            aspect: Double(width) / Double(height))
        var samples: [[Int]?] = []
        for k in 0..<snapshot.count {
            samples.append(position(BackwardsAuroraSceneGeometry.samplePoint(k, snapshot), camera: camera))
        }
        var rings: [[Int]?] = []
        for index in snapshot.checkpoints.indices {
            rings.append(position(BackwardsAuroraSceneGeometry.ringCentre(index, snapshot), camera: camera))
        }
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, trailingLayers: tier.trailingLayers, pulses: tier.pulses,
                           glowShells: tier.glowShells, kinks: snapshot.kinks.count, tear: snapshot.tear,
                           spent: snapshot.spent, budget: snapshot.budget, colours: colours, samples: samples,
                           rings: rings)
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
        if a.trailingLayers != b.trailingLayers || a.pulses != b.pulses || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.trailingLayers) trailing layers, \(b.pulses) pulses, "
                + "\(b.glowShells) glow shells)"
        }
        if a.kinks != b.kinks { return "\(frame): \(a.kinks) kinks, pinned \(b.kinks)" }
        if a.tear != b.tear { return "\(frame): tear \(text(a.tear)), pinned \(text(b.tear))" }
        if a.spent != b.spent { return "\(frame): reversals spent \(a.spent), pinned \(b.spent)" }
        if a.budget != b.budget { return "\(frame): budget \(a.budget), pinned \(b.budget)" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if a.samples.count != b.samples.count {
            return "\(frame): \(a.samples.count) samples, pinned \(b.samples.count)"
        }
        for index in a.samples.indices where !near(a.samples[index], b.samples[index]) {
            return "\(frame): sample \(index) at \(text(a.samples[index])) eighths, pinned " + text(b.samples[index])
        }
        if a.rings.count != b.rings.count { return "\(frame): \(a.rings.count) rings, pinned \(b.rings.count)" }
        for index in a.rings.indices where !near(a.rings[index], b.rings[index]) {
            return "\(frame): checkpoint ring \(index + 1) at \(text(a.rings[index])) eighths, pinned "
                + text(b.rings[index])
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

    /// A seam in words for messages.
    static func text(_ seam: Int?) -> String {
        guard let seam else { return "none" }
        return "seam \(seam)"
    }
}
#endif
