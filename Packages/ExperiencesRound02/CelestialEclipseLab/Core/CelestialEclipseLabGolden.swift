// CelestialEclipseLabGolden — feature 468 (R02-G17-08) T-R02G1708-003 (FR-R02G1708-003, 004; SC-R02G1708-003;
// clarification Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Celestial
// Eclipse Lab: a fixed golden set of 16 frames (certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 at
// presentation time 0, each after all of its certified phase changes but not the run, so actions are spent from the
// gauge and the level is still open, with the default chosen body, shown at the first tick of the predicted timeline
// at which an eclipse is under way (tick 0 when there is none); plus the hero frame: the level the scenario manifest's
// hero scenario opens (seed `manifestSeed`) after that scenario's entries (the certified phase changes, the last moved
// body chosen and the hero tick shown, ``CelestialEclipseLabExperienceCore/heroEntries``), tier 0) and, for each, the
// description of what the frame must show at the frame-check size 1,152 × 768 with the authored camera: every body
// centre at the shown tick (index order), the centre of every shadow lens (the mean of the lens outline at the
// shadow's depth), every halo (on its front body), the playhead and the first actions bar, the counts of bodies, rings,
// shadow lenses, halos, targets, matched targets and lit and total actions bars, and the 21 palette colours (each the
// palette constant of the same name). Positions are rounded to 1/8 pixel (a point that does not project, or projects
// outside the frame, is null) and colours to 8-bit sRGB, the whole serialized as JSON with sorted keys and hashed with
// SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing is drawn here: the description is computed from the
// same snapshot and scene geometry the renderer draws (feature 463), so it is a baseline made by code, never a stored
// picture.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every colour and count is equal; otherwise it names the frame and the first differing value. A pinned digest
// must equal the digest of its pinned description, so a hand-edited entry cannot pass. `writeIfRequested` rewrites the
// file only when `CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1` is set. Debug and automation builds only, like the scenarios;
// the Release symbol check forbids this type. Modelled on `StarlitCartoucheGolden` (feature 458).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Celestial Eclipse Lab (see the file header).
public enum CelestialEclipseLabGolden {
    /// One golden frame: a certified level, a host tier, a presentation time, the phase changes applied from the
    /// opening play, the chosen body and the shown tick.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`CelestialEclipseLabTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions (phase changes, never the run) applied to the level's fresh play before the frame.
        public let actions: [CelestialEclipseLabAction]
        /// The chosen body (presentation state of the adapter); nil for the default choice.
        public let chosenBody: Int?
        /// The shown tick (presentation state of the adapter), 0 … horizon − 1.
        public let tick: Int

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [CelestialEclipseLabAction],
                    chosenBody: Int?, tick: Int) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
            self.chosenBody = chosenBody
            self.tick = tick
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
    /// The presentation time of every frame: 0 (the halo pulse at its peak; positions follow the shown tick).
    public static let time = 0.0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch = "CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN"
    /// The names of the described palette colours (`CelestialEclipseLabPalette`), in the order the comparison checks
    /// them.
    public static let colourNames: [String] = [
        "ink", "inkTop", "speck", "disc", "discShade", "orbit", "fixedFrame", "chosen", "corona", "coronaGlow",
        "crescentShadow", "ember", "window", "matched", "unwanted", "faintEvent", "playhead", "actionsLit",
        "actionsUnlit", "broken", "glow",
    ]

    /// The phase changes a level frame applies: the certified plan's phase changes (never the run; none for a level
    /// that cannot be generated).
    static func openChanges(_ level: Int) -> [CelestialEclipseLabAction] {
        CelestialEclipseLabExperienceCore.certifiedActions(level)
    }

    /// The first tick of `level`'s predicted timeline after `changes` at which an eclipse is under way; 0 when there is
    /// none or the level cannot be generated.
    static func firstEclipseTick(_ level: Int, after changes: [CelestialEclipseLabAction]) -> Int {
        guard let certified = try? CelestialEclipseLabExperienceCore.level(number: level),
              var play = try? CelestialEclipseLabExperienceCore.freshPlay(of: certified) else { return 0 }
        for change in changes {
            do { try play.apply(change, expecting: play.fingerprint) } catch { return 0 }
        }
        for tick in 0..<play.level.horizon
        where !CelestialEclipseLabSceneSnapshot.eclipses(play.level, phases: play.phases, tick: tick).isEmpty {
            return tick
        }
        return 0
    }

    /// The 16 golden frames in their fixed order: each level at tiers 0, 1, 2 with the default chosen body at its first
    /// eclipse tick, then the hero frame (the level the hero scenario opens, seed
    /// ``CelestialEclipseLabExperienceCore/manifestSeed``, after its entries: the certified phase changes, the last
    /// moved body chosen and the hero tick shown; tier 0).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [CelestialEclipseLabAction] = openChanges(level)
            let tick: Int = firstEclipseTick(level, after: actions)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions, chosenBody: nil, tick: tick))
            }
        }
        typealias Core = CelestialEclipseLabExperienceCore
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        let changes: [CelestialEclipseLabAction] = openChanges(heroLevel)
        let heroBody: Int? = changes.last.flatMap { Core.phaseBody(of: $0) }
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: changes, chosenBody: heroBody,
                          tick: Core.heroTick(heroLevel) ?? 0))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play with the frame's phase changes applied, its body
    /// chosen (the default choice when none is given) and its tick shown, at the frame's time.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> CelestialEclipseLabSceneSnapshot {
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.level(number: frame.level)
        var play: CelestialEclipseLabPlay = try CelestialEclipseLabExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        let body: Int = frame.chosenBody ?? CelestialEclipseLabSceneSnapshot.defaultChoice(play.level)
        let tick: Int = min(max(frame.tick, 0), max(play.level.horizon - 1, 0))
        return CelestialEclipseLabSceneSnapshot(play: play, chosenBody: body, shownTick: tick,
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
        let bodies: Int
        let rings: Int
        let lenses: Int
        let halos: Int
        let targets: Int
        let matched: Int
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
        let chosenBody: Int
        let tick: Int
        let counts: Counts
        let colours: [String: Colour]
        let bodies: [[Int]?]
        let lenses: [[Int]?]
        let halos: [[Int]?]
        let playhead: [Int]?
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
            try c.encode(chosenBody, forKey: .chosenBody)
            try c.encode(tick, forKey: .tick)
            try c.encode(counts, forKey: .counts)
            try c.encode(colours, forKey: .colours)
            try c.encode(bodies, forKey: .bodies)
            try c.encode(lenses, forKey: .lenses)
            try c.encode(halos, forKey: .halos)
            try c.encode(playhead, forKey: .playhead)
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
        typealias Palette = CelestialEclipseLabPalette
        switch name {
        case "ink": return Palette.ink
        case "inkTop": return Palette.inkTop
        case "speck": return Palette.speck
        case "disc": return Palette.disc
        case "discShade": return Palette.discShade
        case "orbit": return Palette.orbit
        case "fixedFrame": return Palette.fixedFrame
        case "chosen": return Palette.chosen
        case "corona": return Palette.corona
        case "coronaGlow": return Palette.coronaGlow
        case "crescentShadow": return Palette.crescentShadow
        case "ember": return Palette.ember
        case "window": return Palette.window
        case "matched": return Palette.matched
        case "unwanted": return Palette.unwanted
        case "faintEvent": return Palette.faintEvent
        case "playhead": return Palette.playhead
        case "actionsLit": return Palette.actionsLit
        case "actionsUnlit": return Palette.actionsUnlit
        case "broken": return Palette.broken
        default: return Palette.glow
        }
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected viewport point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project or lies outside the
    /// frame.
    static func position(_ point: SIMD3<Double>, camera: CelestialEclipseLabCamera) -> [Int]? {
        guard let p = CelestialEclipseLabSceneGeometry.project(point, camera: camera),
              p.x >= 0, p.x <= 1, p.y >= 0, p.y <= 1 else { return nil }
        let x: Int = Int((p.x * Double(width) * Double(quantum)).rounded())
        let y: Int = Int((p.y * Double(height) * Double(quantum)).rounded())
        return [x, y]
    }

    /// The positions of `points` with `camera`.
    static func positions(_ points: [SIMD3<Double>], camera: CelestialEclipseLabCamera) -> [[Int]?] {
        var result: [[Int]?] = []
        for point in points { result.append(position(point, camera: camera)) }
        return result
    }

    /// The centre of `eclipse`'s shadow lens: the mean of its outline (``CelestialEclipseLabSceneGeometry/shadowLens``)
    /// at the shadow's depth; nil when the lens is empty.
    static func lensCentre(_ eclipse: CelestialEclipseLabEclipse,
                           _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>? {
        let outline: [SIMD2<Double>] = CelestialEclipseLabSceneGeometry.shadowLens(eclipse, snapshot)
        guard !outline.isEmpty else { return nil }
        var sum: SIMD2<Double> = SIMD2(0, 0)
        for point in outline { sum += point }
        let mean: SIMD2<Double> = sum / Double(outline.count)
        return SIMD3(mean.x, mean.y, CelestialEclipseLabSceneGeometry.shadowZ(eclipse, snapshot))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = CelestialEclipseLabSceneGeometry
        let snapshot: CelestialEclipseLabSceneSnapshot = try snapshot(frame)
        let camera: CelestialEclipseLabCamera = G.camera(snapshot, aspect: Double(width) / Double(height))
        var bodyPoints: [SIMD3<Double>] = []
        for index in snapshot.positions.indices { bodyPoints.append(G.bodyCentre(index, snapshot)) }
        var lenses: [[Int]?] = []
        var haloPoints: [SIMD3<Double>] = []
        for eclipse in snapshot.eclipses {
            if let centre = lensCentre(eclipse, snapshot) {
                lenses.append(position(centre, camera: camera))
            } else {
                lenses.append(nil)
            }
            if G.hasHalo(eclipse) { haloPoints.append(G.bodyCentre(eclipse.front, snapshot)) }
        }
        let actions: Int = max(snapshot.budget, 0)
        let firstBar: [Int]? = actions > 0 ? position(G.actionsBar(0, snapshot), camera: camera) : nil
        var colours: [String: Colour] = [:]
        for name in colourNames { colours[name] = colour(paletteColour(name)) }
        let counts: Counts = Counts(bodies: snapshot.bodies.count, rings: snapshot.bodies.count,
                                    lenses: snapshot.eclipses.count, halos: haloPoints.count,
                                    targets: snapshot.target.count, matched: snapshot.matched,
                                    litActions: G.litActions(snapshot), actions: actions)
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, chosenBody: snapshot.chosenBody, tick: snapshot.shownTick,
                           counts: counts, colours: colours, bodies: positions(bodyPoints, camera: camera),
                           lenses: lenses, halos: positions(haloPoints, camera: camera),
                           playhead: position(G.playhead(snapshot), camera: camera), firstActionsBar: firstBar)
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
    /// (`CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1`); otherwise touches nothing.
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
        if a.chosenBody != b.chosenBody || a.tick != b.tick {
            return "\(frame): body \(a.chosenBody) tick \(a.tick), pinned body \(b.chosenBody) tick \(b.tick)"
        }
        if a.counts != b.counts { return "\(frame): counts differ (pinned \(b.counts))" }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count { return "\(frame): colour set differs" }
        if let found = firstFar("body centre", a.bodies, b.bodies) { return "\(frame): " + found }
        if let found = firstFar("shadow lens", a.lenses, b.lenses) { return "\(frame): " + found }
        if let found = firstFar("halo", a.halos, b.halos) { return "\(frame): " + found }
        if !near(a.playhead, b.playhead) {
            return "\(frame): playhead at \(text(a.playhead)) eighths, pinned \(text(b.playhead))"
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
