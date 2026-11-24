// AcousticConstellatorGolden — feature 428 (R02-G13-08) T-R02G1308-003 (FR-R02G1308-003, 004; SC-R02G1308-003;
// clarification Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Acoustic
// Constellator: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at
// presentation time 0, so tick 0 shows, each after its witness's links and nudges and before its listen, so links,
// gauges and a partly spent moves gauge show while the level is still open; plus the hero frame: the level the scenario
// manifest's hero scenario opens (seed `manifestSeed`) after that scenario's actions (the certified moves without the
// listen, ``AcousticConstellatorExperienceCore/certifiedMoves(_:)``), tier 0) and, for each, the description of what
// the frame must show at the frame-check size 1,152 × 768 with the authored camera: every star centre and every link
// check point (index order), the first coherence bar, the first hold pip and the first moves bar, the counts of stars,
// links, teal links at tick 0, guides (the unlinked symbol pairs), lit coherence bars, lit hold pips and lit and total
// moves bars, and the sky, star, hand, silver, teal, guide, coherence lit and unlit, threshold mark, hold lit and unlit
// and moves lit and unlit colours. Positions are rounded to 1/8 pixel (a point that does not project, or projects
// outside the frame, is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with
// SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing is drawn here: the description is computed from the
// same snapshot and scene geometry the renderer draws (feature 423), so it is a baseline made by code, never a stored
// picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios;
// the Release symbol check forbids this type. Modelled on `HarmonicBridgesGolden` (feature 418).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Acoustic Constellator (see the file header).
public enum AcousticConstellatorGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`AcousticConstellatorTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [AcousticConstellatorAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [AcousticConstellatorAction]) {
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
    /// The presentation time of every frame: 0, so the shown tick is tick 0 (the pulse and the wave shells are shader
    /// work; no described position depends on the time).
    public static let time = 0.0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch = "ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN"
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "sky", "star", "hand", "silver", "teal", "guide", "coherenceLit", "coherenceUnlit", "thresholdMark", "holdLit",
        "holdUnlit", "movesLit", "movesUnlit",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (the level the hero
    /// scenario opens, seed ``AcousticConstellatorExperienceCore/manifestSeed``, after its actions, the certified moves
    /// without the listen (``AcousticConstellatorExperienceCore/certifiedMoves(_:)``), tier 0). A level that cannot be
    /// generated has no actions.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [AcousticConstellatorAction] = AcousticConstellatorExperienceCore.certifiedMoves(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let heroLevel: Int = AcousticConstellatorExperienceCore.levelNumber(
            forSeed: AcousticConstellatorExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time,
                          actions: AcousticConstellatorExperienceCore.certifiedMoves(heroLevel)))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, at the frame's
    /// time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> AcousticConstellatorSceneSnapshot {
        let level: AcousticConstellatorLevel = try AcousticConstellatorExperienceCore.level(number: frame.level)
        var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return AcousticConstellatorSceneSnapshot(play: play, levelNumber: frame.level, time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        let stars: Int
        let links: Int
        let tealLinks: Int
        let guides: Int
        let coherenceLit: Int
        let holdLit: Int
        let movesLit: Int
        let movesTotal: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null.
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let counts: Counts
        let colours: [String: Colour]
        let starCentres: [[Int]?]
        let linkCheckPoints: [[Int]?]
        let firstCoherenceBar: [Int]?
        let firstHoldPip: [Int]?
        let firstMovesBar: [Int]?

        /// Encodes every field; a missing position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(starCentres, forKey: .starCentres)
            try c.encode(linkCheckPoints, forKey: .linkCheckPoints)
            try c.encode(firstCoherenceBar, forKey: .firstCoherenceBar)
            try c.encode(firstHoldPip, forKey: .firstHoldPip)
            try c.encode(firstMovesBar, forKey: .firstMovesBar)
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
        case "sky": return AcousticConstellatorPalette.sky
        case "star": return AcousticConstellatorPalette.star
        case "hand": return AcousticConstellatorPalette.hand
        case "silver": return AcousticConstellatorPalette.silver
        case "teal": return AcousticConstellatorPalette.teal
        case "guide": return AcousticConstellatorPalette.guide
        case "coherenceLit": return AcousticConstellatorPalette.coherenceLit
        case "coherenceUnlit": return AcousticConstellatorPalette.coherenceUnlit
        case "thresholdMark": return AcousticConstellatorPalette.thresholdMark
        case "holdLit": return AcousticConstellatorPalette.holdLit
        case "holdUnlit": return AcousticConstellatorPalette.holdUnlit
        case "movesLit": return AcousticConstellatorPalette.movesLit
        default: return AcousticConstellatorPalette.movesUnlit
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project or lies outside the
    /// frame.
    static func position(_ point: SIMD3<Double>, camera: AcousticConstellatorCamera) -> [Int]? {
        guard let p = AcousticConstellatorSceneGeometry.project(point, camera: camera),
              p.x >= 0, p.x <= 1, p.y >= 0, p.y <= 1 else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: AcousticConstellatorCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        let snapshot: AcousticConstellatorSceneSnapshot = try snapshot(frame)
        let camera: AcousticConstellatorCamera = AcousticConstellatorSceneGeometry.camera(
            snapshot, aspect: Double(width) / Double(height))
        var starPoints: [SIMD3<Double>] = []
        for index in snapshot.stars.indices {
            starPoints.append(AcousticConstellatorSceneGeometry.starCentre(index, snapshot))
        }
        var checkPoints: [SIMD3<Double>] = []
        var teal: Int = 0
        for index in snapshot.links.indices {
            checkPoints.append(AcousticConstellatorSceneGeometry.linkCheckPoint(index, snapshot))
            if snapshot.isTeal(index, at: 0) { teal += 1 }
        }
        let firstCoherenceBar: [Int]? = AcousticConstellatorSceneGeometry.coherenceCount > 0
            ? position(AcousticConstellatorSceneGeometry.coherenceBar(0, snapshot), camera: camera) : nil
        let firstHoldPip: [Int]? = snapshot.hold > 0
            ? position(AcousticConstellatorSceneGeometry.holdPip(0, snapshot), camera: camera) : nil
        let movesTotal: Int = max(snapshot.budget, 0)
        let firstMovesBar: [Int]? = movesTotal > 0
            ? position(AcousticConstellatorSceneGeometry.movesBar(0, snapshot), camera: camera) : nil
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(stars: snapshot.stars.count, links: snapshot.links.count, tealLinks: teal,
                                    guides: snapshot.unlinkedSymbolPairs.count,
                                    coherenceLit: snapshot.coherenceBars(at: 0), holdLit: snapshot.run(at: 0),
                                    movesLit: AcousticConstellatorSceneGeometry.litMoves(snapshot),
                                    movesTotal: movesTotal)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, counts: counts, colours: colours,
                           starCentres: positions(starPoints, camera: camera),
                           linkCheckPoints: positions(checkPoints, camera: camera),
                           firstCoherenceBar: firstCoherenceBar, firstHoldPip: firstHoldPip,
                           firstMovesBar: firstMovesBar)
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

    /// Writes ``manifest()`` to `url` (atomically) only when `environment[writeSwitch]` is `"1"`
    /// (`ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1`); otherwise touches nothing.
    ///
    /// - Returns: whether the file was written.
    /// - Throws: as ``manifest()``; a write failure.
    @discardableResult
    public static func writeIfRequested(
        to url: URL, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Bool {
        guard environment[writeSwitch] == "1" else { return false }
        try manifest().write(to: url, options: [.atomic])
        return true
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
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if let found = firstFar("star centre", a.starCentres, b.starCentres) { return "\(frame): " + found }
        if let found = firstFar("link check point", a.linkCheckPoints, b.linkCheckPoints) { return "\(frame): " + found }
        if !near(a.firstCoherenceBar, b.firstCoherenceBar) {
            return "\(frame): first coherence bar at \(text(a.firstCoherenceBar)) eighths, pinned "
                + text(b.firstCoherenceBar)
        }
        if !near(a.firstHoldPip, b.firstHoldPip) {
            return "\(frame): first hold pip at \(text(a.firstHoldPip)) eighths, pinned \(text(b.firstHoldPip))"
        }
        if !near(a.firstMovesBar, b.firstMovesBar) {
            return "\(frame): first moves bar at \(text(a.firstMovesBar)) eighths, pinned \(text(b.firstMovesBar))"
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
