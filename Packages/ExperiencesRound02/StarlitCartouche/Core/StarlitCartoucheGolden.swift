// StarlitCartoucheGolden — feature 458 (R02-G16-08) T-R02G1608-003 (FR-R02G1608-003, 004; SC-R02G1608-003;
// clarification Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Starlit
// Cartouche: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at
// presentation time 0, each after all of its witness's legs but the last (a one-leg witness applies none), so the
// symbol is part drawn, a partly spent actions gauge shows and the level is still open, with the default choice; plus
// the hero frame: the level the scenario manifest's hero scenario opens (seed `manifestSeed`) after that scenario's
// actions (the certified legs without the last, then that leg's destination and wait chosen,
// ``StarlitCartoucheExperienceCore/heroEntries``), tier 0) and, for each, the description of what the frame must show
// at the frame-check size 1,152 × 768 with the authored camera: every star centre at the current beat (index order),
// the ship, the beacon, the trail midpoint of every flown leg (each accepted leg draws one stroke of the symbol) and
// the first actions bar, the counts of stars, corridors, hazards, active hazards, symbol strokes, drawn strokes and lit
// and total actions bars, and the 22 palette colours (each the palette constant of the same name). Positions are
// rounded to 1/8 pixel (a point that does not project, or projects outside the frame, is null) and colours to 8-bit
// sRGB, the whole serialized as JSON with sorted keys and hashed with SHA-256 (`StableHash`, so the hash needs no
// CryptoKit). Nothing is drawn here: the description is computed from the same snapshot and scene geometry the renderer
// draws (feature 453), so it is a baseline made by code, never a stored picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `STARLIT_CARTOUCHE_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `VoxelOrigamiGolden` (feature 448).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Starlit Cartouche (see the file header).
public enum StarlitCartoucheGolden {
    /// One golden frame: a certified level, a host tier, a presentation time, the legs applied from the opening play
    /// and the chosen destination and wait.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`StarlitCartoucheTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [StarlitCartoucheAction]
        /// The chosen destination star (presentation state of the adapter); nil for the default choice.
        public let chosenStar: Int?
        /// The chosen wait, 0 … 8 (presentation state of the adapter).
        public let chosenWait: Int

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [StarlitCartoucheAction],
                    chosenStar: Int?, chosenWait: Int) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
            self.chosenStar = chosenStar
            self.chosenWait = chosenWait
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
    /// The presentation time of every frame: 0 (the firmament at its start; the stars' positions follow the beat).
    public static let time = 0.0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch = "STARLIT_CARTOUCHE_WRITE_GOLDEN"
    /// The names of the described palette colours (`StarlitCartouchePalette`), in the order the comparison checks them.
    public static let colourNames: [String] = [
        "night", "nightTop", "speck", "pearl", "pearlShade", "corridor", "symbolDash", "trail", "trailGlow", "ship",
        "shipGlow", "beacon", "chosen", "hazardActive", "hazardIdle", "actionsLit", "actionsUnlit", "beatTrack",
        "waitLit", "waitUnlit", "broken", "glow",
    ]

    /// The legs a level frame applies: the certified legs of `level` without the last (none for a one-leg plan or a
    /// level that cannot be generated).
    static func openLegs(_ level: Int) -> [StarlitCartoucheAction] {
        Array(StarlitCartoucheExperienceCore.certifiedActions(level).dropLast())
    }

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2 with the default choice, then the hero
    /// frame (the level the hero scenario opens, seed ``StarlitCartoucheExperienceCore/manifestSeed``, after its
    /// actions: the certified legs without the last, then that leg's destination and wait chosen; tier 0).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [StarlitCartoucheAction] = openLegs(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions, chosenStar: nil, chosenWait: 0))
            }
        }
        typealias Core = StarlitCartoucheExperienceCore
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let certified: [StarlitCartoucheAction] = Core.certifiedActions(heroLevel)
        let heroStar: Int? = certified.last.map { Core.destination(of: $0) }
        let heroWait: Int = certified.last.map { Core.wait(of: $0) } ?? 0
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: openLegs(heroLevel),
                          chosenStar: heroStar, chosenWait: heroWait))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied and its
    /// destination and wait chosen (the default choice when none is given), at the frame's time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> StarlitCartoucheSceneSnapshot {
        let level: StarlitCartoucheLevel = try StarlitCartoucheExperienceCore.level(number: frame.level)
        var play: StarlitCartouchePlay = try StarlitCartoucheExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        let star: Int = frame.chosenStar ?? StarlitCartoucheSceneSnapshot.defaultChoice(play.level, star: play.star)
        return StarlitCartoucheSceneSnapshot(play: play, chosenStar: star, chosenWait: frame.chosenWait,
                                             levelNumber: frame.level, time: frame.time)
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
        let corridors: Int
        let hazards: Int
        let activeHazards: Int
        let symbol: Int
        let drawn: Int
        let litActions: Int
        let actions: Int
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel, or null.
    struct Description: Codable, Equatable {
        let name: String
        let level: Int
        let tier: Int
        let width: Int
        let height: Int
        let quantum: Int
        let chosenStar: Int
        let chosenWait: Int
        let counts: Counts
        let colours: [String: Colour]
        let stars: [[Int]?]
        let trails: [[Int]?]
        let ship: [Int]?
        let beacon: [Int]?
        let firstActionsBar: [Int]?

        /// Encodes every field; a missing position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(chosenStar, forKey: .chosenStar)
            try c.encode(chosenWait, forKey: .chosenWait)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(stars, forKey: .stars)
            try c.encode(trails, forKey: .trails)
            try c.encode(ship, forKey: .ship)
            try c.encode(beacon, forKey: .beacon)
            try c.encode(firstActionsBar, forKey: .firstActionsBar)
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

    /// The palette colour named `name` (one of ``colourNames``): the palette constant of the same name.
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        typealias Palette = StarlitCartouchePalette
        switch name {
        case "night": return Palette.night
        case "nightTop": return Palette.nightTop
        case "speck": return Palette.speck
        case "pearl": return Palette.pearl
        case "pearlShade": return Palette.pearlShade
        case "corridor": return Palette.corridor
        case "symbolDash": return Palette.symbolDash
        case "trail": return Palette.trail
        case "trailGlow": return Palette.trailGlow
        case "ship": return Palette.ship
        case "shipGlow": return Palette.shipGlow
        case "beacon": return Palette.beacon
        case "chosen": return Palette.chosen
        case "hazardActive": return Palette.hazardActive
        case "hazardIdle": return Palette.hazardIdle
        case "actionsLit": return Palette.actionsLit
        case "actionsUnlit": return Palette.actionsUnlit
        case "beatTrack": return Palette.beatTrack
        case "waitLit": return Palette.waitLit
        case "waitUnlit": return Palette.waitUnlit
        case "broken": return Palette.broken
        default: return Palette.glow
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project or lies outside the
    /// frame.
    static func position(_ point: SIMD3<Double>, camera: StarlitCartoucheCamera) -> [Int]? {
        guard let p = StarlitCartoucheSceneGeometry.project(point, camera: camera),
              p.x >= 0, p.x <= 1, p.y >= 0, p.y <= 1 else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: StarlitCartoucheCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = StarlitCartoucheSceneGeometry
        let snapshot: StarlitCartoucheSceneSnapshot = try snapshot(frame)
        let camera: StarlitCartoucheCamera = G.camera(snapshot, aspect: Double(width) / Double(height))
        var starPoints: [SIMD3<Double>] = []
        for index in snapshot.positions.indices { starPoints.append(G.starCentre(index, snapshot)) }
        var trailPoints: [SIMD3<Double>] = []
        for leg in snapshot.legs.indices { trailPoints.append(G.trailMidpoint(leg, snapshot)) }
        let actions: Int = max(snapshot.budget, 0)
        let firstBar: [Int]? = actions > 0 ? position(G.actionsBar(0, snapshot), camera: camera) : nil
        var active: Int = 0
        for flag in snapshot.active where flag { active += 1 }
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(stars: snapshot.stars.count, corridors: snapshot.corridors.count,
                                    hazards: snapshot.hazards.count, activeHazards: active,
                                    symbol: snapshot.symbol.count, drawn: snapshot.drawn.count,
                                    litActions: G.litActions(snapshot), actions: actions)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, chosenStar: snapshot.chosenStar, chosenWait: snapshot.chosenWait,
                           counts: counts, colours: colours, stars: positions(starPoints, camera: camera),
                           trails: positions(trailPoints, camera: camera),
                           ship: position(G.shipCentre(snapshot), camera: camera),
                           beacon: position(G.starCentre(snapshot.beacon, snapshot), camera: camera),
                           firstActionsBar: firstBar)
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
    /// (`STARLIT_CARTOUCHE_WRITE_GOLDEN=1`); otherwise touches nothing.
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
        if a.chosenStar != b.chosenStar || a.chosenWait != b.chosenWait {
            return "\(frame): choice star \(a.chosenStar) wait \(a.chosenWait), pinned star \(b.chosenStar) wait "
                + "\(b.chosenWait)"
        }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if let found = firstFar("star centre", a.stars, b.stars) { return "\(frame): " + found }
        if let found = firstFar("trail midpoint", a.trails, b.trails) { return "\(frame): " + found }
        if !near(a.ship, b.ship) { return "\(frame): ship at \(text(a.ship)) eighths, pinned \(text(b.ship))" }
        if !near(a.beacon, b.beacon) {
            return "\(frame): beacon at \(text(a.beacon)) eighths, pinned \(text(b.beacon))"
        }
        if !near(a.firstActionsBar, b.firstActionsBar) {
            return "\(frame): first actions bar at \(text(a.firstActionsBar)) eighths, pinned "
                + text(b.firstActionsBar)
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
