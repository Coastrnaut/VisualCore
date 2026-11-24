// MoonlitMechanismGolden — feature 438 (R02-G14-08) T-R02G1408-003 (FR-R02G1408-003, 004; SC-R02G1408-003;
// clarification Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Moonlit
// Mechanism: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at
// presentation time 0, key frame 0 shown, each after its witness's turns, re-seats and lamp steps and before its run, so
// the set-up casts its shadows and a partly spent moves gauge shows while the level is still open; plus the hero frame:
// the level the scenario manifest's hero scenario opens (seed `manifestSeed`) after that scenario's actions (the
// certified moves without the run, ``MoonlitMechanismExperienceCore/certifiedMoves(_:)``), tier 0) and, for each, the
// description of what the frame must show at the frame-check size 1,152 × 768 with the authored camera: every cast-cell
// centre of the shown key frame, every gear centre and rim check point, every key-frame card centre (index order), the
// first alignment pip, the lamp centre and the first moves bar, the counts of gears, cast cells, target cells, missing
// and stray cells, forbidden cells, lit cards (covered fraction above 0), aligned pips (meshes with error 0) and lit
// and total moves bars, and the night, paper, ink, gear, rim, blade, lamp, card lit and unlit, pip, moves lit and unlit
// and broken colours (`pip` is the lit alignment pip, ``MoonlitMechanismPalette/alignLit``; every other name is the
// palette constant of the same name). Positions are rounded to 1/8 pixel (a point that does not project, or projects
// outside the frame, is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with
// SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing is drawn here: the description is computed from the
// same snapshot and scene geometry the renderer draws (feature 433), so it is a baseline made by code, never a stored
// picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `MOONLIT_MECHANISM_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios; the
// Release symbol check forbids this type. Modelled on `AcousticConstellatorGolden` (feature 428).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Moonlit Mechanism (see the file header).
public enum MoonlitMechanismGolden {
    /// One golden frame: a certified level, a host tier, a presentation time and the actions applied from the opening
    /// play.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`MoonlitMechanismTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions applied to the level's fresh play before the frame.
        public let actions: [MoonlitMechanismAction]

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [MoonlitMechanismAction]) {
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
    /// The presentation time of every frame: 0 (the glow and the gear motion between key frames are presentation
    /// work; no described position depends on the time).
    public static let time = 0.0
    /// The key frame every golden frame shows.
    public static let shownFrame = 0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch = "MOONLIT_MECHANISM_WRITE_GOLDEN"
    /// The names of the described palette colours, in the order the comparison checks them.
    public static let colourNames: [String] = [
        "night", "paper", "ink", "gear", "rim", "blade", "lamp", "cardLit", "cardUnlit", "pip", "movesLit",
        "movesUnlit", "broken",
    ]

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2, then the hero frame (the level the hero
    /// scenario opens, seed ``MoonlitMechanismExperienceCore/manifestSeed``, after its actions, the certified moves
    /// without the run (``MoonlitMechanismExperienceCore/certifiedMoves(_:)``), tier 0). A level that cannot be
    /// generated has no actions.
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [MoonlitMechanismAction] = MoonlitMechanismExperienceCore.certifiedMoves(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions))
            }
        }
        let heroLevel: Int = MoonlitMechanismExperienceCore.levelNumber(
            forSeed: MoonlitMechanismExperienceCore.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time,
                          actions: MoonlitMechanismExperienceCore.certifiedMoves(heroLevel)))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's actions applied, key frame 0
    /// shown, at the frame's time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> MoonlitMechanismSceneSnapshot {
        let level: MoonlitMechanismLevel = try MoonlitMechanismExperienceCore.level(number: frame.level)
        var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return MoonlitMechanismSceneSnapshot(play: play, shownFrame: shownFrame, levelNumber: frame.level,
                                             time: frame.time)
    }

    /// An 8-bit sRGB colour.
    struct Colour: Codable, Equatable {
        let r: Int
        let g: Int
        let b: Int
    }

    /// The counts of a description.
    struct Counts: Codable, Equatable {
        let gears: Int
        let cast: Int
        let targets: Int
        let missing: Int
        let stray: Int
        let forbidden: Int
        let litCards: Int
        let alignedPips: Int
        let litMoves: Int
        let moves: Int
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
        let castCentres: [[Int]?]
        let gearCentres: [[Int]?]
        let rimPoints: [[Int]?]
        let cardCentres: [[Int]?]
        let firstPip: [Int]?
        let lamp: [Int]?
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
            try c.encode(castCentres, forKey: .castCentres)
            try c.encode(gearCentres, forKey: .gearCentres)
            try c.encode(rimPoints, forKey: .rimPoints)
            try c.encode(cardCentres, forKey: .cardCentres)
            try c.encode(firstPip, forKey: .firstPip)
            try c.encode(lamp, forKey: .lamp)
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

    /// The palette colour named `name` (one of ``colourNames``): `pip` is the lit alignment pip
    /// (``MoonlitMechanismPalette/alignLit``); every other name is the palette constant of the same name.
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        switch name {
        case "night": return MoonlitMechanismPalette.night
        case "paper": return MoonlitMechanismPalette.paper
        case "ink": return MoonlitMechanismPalette.ink
        case "gear": return MoonlitMechanismPalette.gear
        case "rim": return MoonlitMechanismPalette.rim
        case "blade": return MoonlitMechanismPalette.blade
        case "lamp": return MoonlitMechanismPalette.lamp
        case "cardLit": return MoonlitMechanismPalette.cardLit
        case "cardUnlit": return MoonlitMechanismPalette.cardUnlit
        case "pip": return MoonlitMechanismPalette.alignLit
        case "movesLit": return MoonlitMechanismPalette.movesLit
        case "movesUnlit": return MoonlitMechanismPalette.movesUnlit
        default: return MoonlitMechanismPalette.broken
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project or lies outside the
    /// frame.
    static func position(_ point: SIMD3<Double>, camera: MoonlitMechanismCamera) -> [Int]? {
        guard let p = MoonlitMechanismSceneGeometry.project(point, camera: camera),
              p.x >= 0, p.x <= 1, p.y >= 0, p.y <= 1 else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: MoonlitMechanismCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = MoonlitMechanismSceneGeometry
        let snapshot: MoonlitMechanismSceneSnapshot = try snapshot(frame)
        let camera: MoonlitMechanismCamera = G.camera(snapshot, aspect: Double(width) / Double(height))
        var castPoints: [SIMD3<Double>] = []
        for cell in snapshot.cast { castPoints.append(G.cellCentre(cell, snapshot)) }
        var gearPoints: [SIMD3<Double>] = []
        var rimPoints: [SIMD3<Double>] = []
        for index in snapshot.gears.indices {
            gearPoints.append(G.gearCentre(index, snapshot))
            rimPoints.append(G.gearRimCheckPoint(index, snapshot))
        }
        var cardPoints: [SIMD3<Double>] = []
        var litCards: Int = 0
        for index in snapshot.keyFrames.indices {
            cardPoints.append(G.card(index, snapshot))
            if G.cardFraction(index, snapshot) > 0 { litCards += 1 }
        }
        let pips: Int = G.pipCount(snapshot)
        var alignedPips: Int = 0
        for index in 0..<pips where G.isPipLit(index, snapshot) { alignedPips += 1 }
        let firstPip: [Int]? = pips > 0 ? position(G.alignmentPip(0, snapshot), camera: camera) : nil
        let moves: Int = max(snapshot.budget, 0)
        let firstMovesBar: [Int]? = moves > 0 ? position(G.movesBar(0, snapshot), camera: camera) : nil
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(gears: snapshot.gears.count, cast: snapshot.cast.count,
                                    targets: snapshot.target.count, missing: snapshot.missingCells.count,
                                    stray: snapshot.strayCells.count, forbidden: snapshot.forbidden.count,
                                    litCards: litCards, alignedPips: alignedPips, litMoves: G.litMoves(snapshot),
                                    moves: moves)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, counts: counts, colours: colours,
                           castCentres: positions(castPoints, camera: camera),
                           gearCentres: positions(gearPoints, camera: camera),
                           rimPoints: positions(rimPoints, camera: camera),
                           cardCentres: positions(cardPoints, camera: camera),
                           firstPip: firstPip, lamp: position(G.lampCentre(snapshot), camera: camera),
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
    /// (`MOONLIT_MECHANISM_WRITE_GOLDEN=1`); otherwise touches nothing.
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
        if let found = firstFar("cast centre", a.castCentres, b.castCentres) { return "\(frame): " + found }
        if let found = firstFar("gear centre", a.gearCentres, b.gearCentres) { return "\(frame): " + found }
        if let found = firstFar("rim point", a.rimPoints, b.rimPoints) { return "\(frame): " + found }
        if let found = firstFar("card centre", a.cardCentres, b.cardCentres) { return "\(frame): " + found }
        if !near(a.firstPip, b.firstPip) {
            return "\(frame): first pip at \(text(a.firstPip)) eighths, pinned \(text(b.firstPip))"
        }
        if !near(a.lamp, b.lamp) {
            return "\(frame): lamp at \(text(a.lamp)) eighths, pinned \(text(b.lamp))"
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
