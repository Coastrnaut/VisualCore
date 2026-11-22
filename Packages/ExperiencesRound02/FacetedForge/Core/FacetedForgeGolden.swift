// FacetedForgeGolden — feature 378 (R02-G08-08) T-R02G0808-003 (FR-R02G0808-003, 004; SC-R02G0808-003; clarification
// Q3; research R2, R3, R5, R6; data-model.md; contracts/api.md). The code-only visual baseline of Faceted Forge: a
// fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at presentation time 1
// s, fully opened, each after its certified solution's first min(smallest − 1, 2) cuts, so pieces and spent cut bars
// show while the level is not won; plus the hero frame: level 1 after the hero scenario's first neutral cut, tier 0)
// and, for each, the description of what the frame must show at the frame-check size 1,152 × 768 with the authored
// camera and the initial preview choice (`FacetedForgePreviewChoice.initial`): every piece centre in canonical piece
// order and the preview centre (null when there is no preview), the cuts spent and the budget, the tier's detail (bevel
// segments, dispersion layers, glow shells) and the ground, ice, highlight, ruby, amber, lattice, sliver, spent and
// unspent colours. Positions are rounded to 1/8 pixel (an off-screen point is null) and colours to 8-bit sRGB, the
// whole serialized as JSON with sorted keys and hashed with SHA-256 (`StableHash`). Nothing is drawn here: the
// description is computed from the same snapshot and scene geometry the renderer draws (feature 373), so it is a
// baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal (the system's trigonometry may differ in the last bit between macOS
// releases); otherwise it names the frame and the first differing value. A pinned digest must equal the digest of its
// pinned description, so a hand-edited entry cannot pass. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `AmethystEscapeGolden` (feature 368).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Faceted Forge (see the file header).
public enum FacetedForgeGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the cuts applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`FacetedForgeTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [FacetedForgeAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [FacetedForgeAction]) {
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
    /// At most this many certified cuts are applied, and always fewer than the certified solution's whole length.
    public static let cuts = 2
    /// The presentation time of every frame: past the 0.4 s opening, so the pieces are fully opened.
    public static let time = 1.0
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "ground", "ice", "highlight", "ruby", "amber", "lattice", "sliver", "spent", "unspent",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (level 1 after the
    /// hero scenario's first cut, ``FacetedForgeExperienceCore/inputActions`` [0], tier 0). A level that cannot be
    /// generated has no actions (``FacetedForgeExperienceCore/certifiedActions(_:)`` is empty).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [FacetedForgeAction] = certifiedPrefix(level: level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let hero: [FacetedForgeAction] = Array(FacetedForgeExperienceCore.inputActions.prefix(1))
        let heroLevel: Int = FacetedForgeExperienceCore.levelNumber(forSeed: FacetedForgeExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: hero))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The first min(smallest − 1, ``cuts``) cuts of `level`'s certified solution, so the level is not won.
    static func certifiedPrefix(level: Int) -> [FacetedForgeAction] {
        let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(level)
        return Array(actions.prefix(max(0, min(actions.count - 1, cuts))))
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, the initial
    /// preview choice of that play, at the frame's time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> FacetedForgeSceneSnapshot {
        let level: FacetedForgeLevel = try FacetedForgeExperienceCore.level(number: frame.level)
        var play: FacetedForgePlay = try FacetedForgeExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        let choice: FacetedForgePreviewChoice = FacetedForgePreviewChoice.initial(play)
        return FacetedForgeSceneSnapshot(play: play, levelNumber: frame.level, choice: choice, time: frame.time)
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
        let bevelSegments: Int
        let dispersionLayers: Int
        let glowShells: Int
        let cuts: Int
        let budget: Int
        let colours: [String: Colour]
        let pieces: [[Int]?]
        let preview: [Int]?

        /// Encodes every field; a missing preview is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(bevelSegments, forKey: .bevelSegments)
            try c.encode(dispersionLayers, forKey: .dispersionLayers)
            try c.encode(glowShells, forKey: .glowShells)
            try c.encode(cuts, forKey: .cuts)
            try c.encode(budget, forKey: .budget)
            try c.encode(colours, forKey: .colours)
            try c.encode(pieces, forKey: .pieces)
            try c.encode(preview, forKey: .preview)
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
        case "ground": return FacetedForgePalette.ground
        case "ice": return FacetedForgePalette.ice
        case "highlight": return FacetedForgePalette.highlight
        case "ruby": return FacetedForgePalette.ruby
        case "amber": return FacetedForgePalette.amber
        case "lattice": return FacetedForgePalette.lattice
        case "sliver": return FacetedForgePalette.sliver
        case "spent": return FacetedForgePalette.spent
        default: return FacetedForgePalette.unspent
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
        let snapshot: FacetedForgeSceneSnapshot = try snapshot(frame)
        let tier: FacetedForgeTier = FacetedForgeTier.of(frame.tier)
        let camera: FacetedForgeCamera = FacetedForgeSceneGeometry.camera(snapshot,
                                                                          aspect: Double(width) / Double(height))
        var pieces: [[Int]?] = []
        for index in snapshot.pieces.indices {
            let centre: SIMD3<Double> = FacetedForgeSceneGeometry.pieceCentre(index, snapshot)
            pieces.append(position(FacetedForgeSceneGeometry.pixel(centre, camera: camera, width: width,
                                                                   height: height)))
        }
        var preview: [Int]? = nil
        if let centre = FacetedForgeSceneGeometry.previewCentre(snapshot) {
            preview = position(FacetedForgeSceneGeometry.pixel(centre, camera: camera, width: width, height: height))
        }
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, bevelSegments: tier.bevelSegments,
                           dispersionLayers: tier.dispersionLayers, glowShells: tier.glowShells,
                           cuts: snapshot.cuts, budget: snapshot.budget, colours: colours, pieces: pieces,
                           preview: preview)
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
        if a.bevelSegments != b.bevelSegments || a.dispersionLayers != b.dispersionLayers
            || a.glowShells != b.glowShells {
            return "\(frame): tier detail differs (pinned \(b.bevelSegments) bevel segments, \(b.dispersionLayers) "
                + "dispersion layers, \(b.glowShells) glow shells)"
        }
        if a.cuts != b.cuts { return "\(frame): cuts \(a.cuts), pinned \(b.cuts)" }
        if a.budget != b.budget { return "\(frame): budget \(a.budget), pinned \(b.budget)" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if a.pieces.count != b.pieces.count {
            return "\(frame): \(a.pieces.count) pieces, pinned \(b.pieces.count)"
        }
        for index in a.pieces.indices where !near(a.pieces[index], b.pieces[index]) {
            return "\(frame): piece \(index) centre at \(text(a.pieces[index])) eighths, pinned "
                + text(b.pieces[index])
        }
        if !near(a.preview, b.preview) {
            return "\(frame): preview centre at \(text(a.preview)) eighths, pinned \(text(b.preview))"
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
