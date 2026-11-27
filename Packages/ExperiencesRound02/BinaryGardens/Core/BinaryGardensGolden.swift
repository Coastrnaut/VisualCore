// BinaryGardensGolden — feature 508 (R02-G21-08) T-R02G2108-003 (FR-R02G2108-003, 004; SC-R02G2108-003; clarification
// Q3; data-model.md "Frame description"; contracts/api.md). The code-only visual baseline of Binary Gardens: a fixed
// golden set of 17 frames — certified levels 1, 21, 41, 61 and 81 at host tiers 0, 1 and 2 (the feature-503 frame-check
// levels), then level 25 at tier 0 (the first level whose tilt dial spans the full range 0 … 3, so the dial is pinned
// too), each after all of the witness's actions (the certified plan, the stored witness
// `docs/games/binary-gardens/levels/NNN.witness.json` without its final run) but not the run, so actions are spent from
// the actions bars, the predicted run is the winning one and the level is still open, with tick 24 shown (as the
// feature-503 frame checks send `clock.show [24]`), at presentation time 0, the authored camera (the view orbit at
// rest), no preview and no inspected world; then the hero frame: the level the scenario manifest's hero scenario opens
// (seed `manifestSeed`) after its entries (the certified plan and the hero tick shown,
// ``BinaryGardensExperienceCore/heroTick(_:)``), tier 0.
//
// For each frame the description holds what the frame must show at the frame-check size 1,152 × 768 with the authored
// camera: the projected pixel positions of the barycentre, every world's centre (world order), both stars' centres,
// the first gauge plate's left margin, the first actions bar and, when the level has a tilt dial, the first tilt pip
// (null otherwise); the counts of rings, rings a star stands on, worlds, worlds in each of the five bands at the shown
// tick (lethal low, dim, comfortable, bright, lethal high), gauge cells in each band over all worlds, short window
// brackets (worlds whose drawn bracket is the short one), lit and total tilt pips, lit and total luminosity pips, lit
// and total actions bars and broken elements (the drawn marks of a failed play: a frozen or scorched world's ring and
// cell, an unstable world's bracket pieces or its lone required tick, a wilted or bleached world's bloom marker; 0 on
// an open level); the shown tick, the tilt, each star's ring, phase and luminosity index and each world's integral and
// longest comfortable window with its start; every colour of `BinaryGardensPalette.all` (27 today) as 8-bit sRGB; and
// every material of ``BinaryGardensShaders/materials`` (42 today, codes 0 … 41) with its palette constant name. The
// palette and the material table are taken whole, so a colour or material a later feature adds is pinned with the
// rest. Positions are rounded to 1/8 pixel (a point behind the eye, which does not project, is null). The whole is
// serialized as JSON with sorted keys and hashed with SHA-256 (`StableHash`, so the hash needs no CryptoKit). Nothing
// is drawn here: the description is computed from the same snapshot and scene geometry the renderer draws (feature
// 503), so it is a baseline made by code, never a stored picture. The tiers share every position and count (only the
// cube-sphere tessellation, the corona rays, the trails, the motes and the glow differ between tiers, and none of them
// is described), so the three tiers of a level differ only in their identity.
//
// The pinned file (`golden-frames.json`) holds every description and its digest. `compare` accepts a recomputed frame
// when its digest equals the pinned one, or else when every position lies within one 1/8-pixel quantum of the pinned
// one and every count, value, colour and material entry is equal; otherwise it names the frame and the first
// differing value. A pinned digest must equal the digest of its pinned description, so a hand-edited entry cannot
// pass. `writeIfRequested` rewrites the file only when `BINARY_GARDENS_WRITE_GOLDEN=1` is set. Debug and automation
// builds only, like the scenarios; the Release symbol check forbids this type. Modelled on `MushroomWeatherGolden`
// (feature 498).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreMath

/// The code-only golden frames of Binary Gardens (see the file header).
public enum BinaryGardensGolden {
    /// One golden frame: a certified level, a host tier, a presentation time, the actions applied to the level's fresh
    /// play and the shown tick.
    public struct Frame: Sendable, Equatable {
        /// The frame's name in the pinned file, for example `level-021-tier-1`, `level-025-tier-0` or `hero`.
        public let name: String
        /// The certified level number, 1 … 100.
        public let level: Int
        /// The host tier, 0 … 2 (`BinaryGardensTier.of`).
        public let tier: Int
        /// The presentation time in seconds.
        public let time: Double
        /// The kernel actions (rings, phases, luminosities and tilts, never the run) applied to the level's fresh
        /// play.
        public let actions: [BinaryGardensAction]
        /// The shown tick, 1 … 48.
        public let tick: Int

        /// A frame of the given values.
        public init(name: String, level: Int, tier: Int, time: Double, actions: [BinaryGardensAction], tick: Int) {
            self.name = name
            self.level = level
            self.tier = tier
            self.time = time
            self.actions = actions
            self.tick = tick
        }
    }

    /// The frame-check width in pixels.
    public static let width: Int = 1_152
    /// The frame-check height in pixels.
    public static let height: Int = 768
    /// The schema of the pinned file.
    public static let schema: Int = 1
    /// Positions are stored in units of 1/`quantum` pixel.
    public static let quantum: Int = 8
    /// The levels of the golden set drawn at every tier, one per band (the feature-503 frame-check levels).
    public static let levels: [Int] = [1, 21, 41, 61, 81]
    /// The level drawn at tier 0 for its tilt dial: the first level with the full tilt range 0 … 3.
    public static let dialLevel: Int = 25
    /// The tick every level frame shows (as the feature-503 frame checks).
    public static let tick: Int = 24
    /// The presentation time of every frame: 0 (positions follow the shown tick, never the time).
    public static let time: Double = 0.0
    /// The environment switch that lets ``writeIfRequested(to:environment:)`` rewrite the pinned file.
    public static let writeSwitch: String = "BINARY_GARDENS_WRITE_GOLDEN"
    /// The bands in the order the counts list them: lethal low, dim, comfortable, bright, lethal high.
    static let bands: [BinaryGardensBand] = [.lethalLow, .dim, .comfortable, .bright, .lethalHigh]

    /// The names of the described palette colours (`BinaryGardensPalette.all`), in the order the comparison checks
    /// them.
    public static var colourNames: [String] {
        var names: [String] = []
        for entry in BinaryGardensPalette.all { names.append(entry.name) }
        return names
    }

    /// The actions a frame of `level` applies: the certified plan's actions (the witness's actions without the run;
    /// none for a level that cannot be generated).
    static func openActions(_ level: Int) -> [BinaryGardensAction] {
        BinaryGardensExperienceCore.certifiedActions(level)
    }

    /// The 17 golden frames in their fixed order: each of ``levels`` at tiers 0, 1, 2 with tick 24 shown, then
    /// ``dialLevel`` at tier 0 with tick 24 shown, then the hero frame (the level the hero scenario opens, seed
    /// ``BinaryGardensExperienceCore/manifestSeed``, after its entries: the certified plan and the hero tick shown;
    /// tier 0; tick 48 when the level has no hero tick).
    public static var frames: [Frame] {
        var list: [Frame] = []
        for level in levels {
            let actions: [BinaryGardensAction] = openActions(level)
            for tier in 0..<3 {
                list.append(Frame(name: name(level: level, tier: tier), level: level, tier: tier, time: time,
                                  actions: actions, tick: tick))
            }
        }
        list.append(Frame(name: name(level: dialLevel, tier: 0), level: dialLevel, tier: 0, time: time,
                          actions: openActions(dialLevel), tick: tick))
        typealias Core = BinaryGardensExperienceCore
        let heroLevel: Int = Core.levelNumber(forSeed: Core.manifestSeed)
        list.append(Frame(name: "hero", level: heroLevel, tier: 0, time: time, actions: openActions(heroLevel),
                          tick: Core.heroTick(heroLevel) ?? BinaryGardensSky.cycle))
        return list
    }

    /// `level-NNN-tier-T`.
    static func name(level: Int, tier: Int) -> String {
        let digits: String = String(level)
        return "level-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits + "-tier-\(tier)"
    }

    /// The snapshot `frame` shows: the certified level's fresh play (begun, past its tutorial) with the frame's
    /// actions applied and its tick shown (clamped to 1 … 48), at the frame's time; no preview and no inspected world.
    ///
    /// - Throws: the kernel's refusal of the level or of an action.
    public static func snapshot(_ frame: Frame) throws -> BinaryGardensSceneSnapshot {
        let level: BinaryGardensLevel = try BinaryGardensExperienceCore.level(number: frame.level)
        var play: BinaryGardensPlay = try BinaryGardensExperienceCore.freshPlay(of: level)
        for action in frame.actions { try play.apply(action, expecting: play.fingerprint) }
        return BinaryGardensSceneSnapshot(play: play, shownTick: frame.tick, levelNumber: frame.level,
                                          time: frame.time)
    }

    /// The counts of a description (clarification Q3).
    struct Counts: Codable, Equatable {
        /// Rings of the level.
        let rings: Int
        /// Rings a star stands on (1 when both stars share one).
        let starRings: Int
        /// Worlds.
        let worlds: Int
        /// Worlds in each band at the shown tick: lethal low, dim, comfortable, bright, lethal high.
        let worldsByBand: [Int]
        /// Gauge cells in each band over all worlds, in the same order.
        let cellsByBand: [Int]
        /// Worlds whose drawn window bracket is the short one (a window shorter than the required one).
        let shortBrackets: Int
        /// Lit tilt pips (1 with a tilt dial, else 0).
        let tiltPipsLit: Int
        /// Tilt pips (maximum tilt + 1 with a tilt dial, else 0).
        let tiltPips: Int
        /// Lit luminosity pips over both stars.
        let luminosityPipsLit: Int
        /// Luminosity pips over both stars.
        let luminosityPips: Int
        /// Lit actions bars (the actions left).
        let actionsLit: Int
        /// Actions bars in all (the budget).
        let actions: Int
        /// Elements drawn in the broken colour (0 unless the play failed).
        let broken: Int

        /// The count names in the order the comparison checks them, with their values.
        var named: [(name: String, value: [Int])] {
            [("rings", [rings]), ("starRings", [starRings]), ("worlds", [worlds]), ("worldsByBand", worldsByBand),
             ("cellsByBand", cellsByBand), ("shortBrackets", [shortBrackets]), ("tiltPipsLit", [tiltPipsLit]),
             ("tiltPips", [tiltPips]), ("luminosityPipsLit", [luminosityPipsLit]),
             ("luminosityPips", [luminosityPips]), ("actionsLit", [actionsLit]), ("actions", [actions]),
             ("broken", [broken])]
        }
    }

    /// One star's arrangement: its ring index, phase and luminosity index.
    struct StarValue: Codable, Equatable {
        /// The ring index.
        let ring: Int
        /// The phase step.
        let phase: Int
        /// The luminosity index.
        let luminosity: Int
    }

    /// One world's light over the cycle: its integral, longest comfortable window and that window's start tick.
    struct WindowValue: Codable, Equatable {
        /// The integrated flux, in milliflux.
        let integral: Int
        /// The longest comfortable window, in ticks.
        let window: Int
        /// Its start tick (0 when no tick is comfortable).
        let start: Int
    }

    /// One material of the table: its code, Swift name and GLSL palette constant.
    struct MaterialEntry: Codable, Equatable {
        /// The material code.
        let code: Int
        /// The Swift case name.
        let name: String
        /// The palette constant the system vertex shader selects.
        let constant: String
    }

    /// The description of one frame (see the file header). A position is `[x, y]` in 1/``quantum`` pixel from the
    /// top left (y down), or null; a colour is `[r, g, b]` in 8 bits.
    struct Description: Codable, Equatable {
        /// The frame's name.
        let name: String
        /// The level number.
        let level: Int
        /// The tier.
        let tier: Int
        /// The frame width in pixels.
        let width: Int
        /// The frame height in pixels.
        let height: Int
        /// Positions are in 1/`quantum` pixel.
        let quantum: Int
        /// The shown tick.
        let tick: Int
        /// The tilt step.
        let tilt: Int
        /// The element counts.
        let counts: Counts
        /// Each star's ring, phase and luminosity index, star 1 first.
        let starValues: [StarValue]
        /// Each world's integral, longest comfortable window and its start, world order.
        let windows: [WindowValue]
        /// The palette colours by name.
        let colours: [String: [Int]]
        /// The material table, code order.
        let materials: [MaterialEntry]
        /// The barycentre.
        let barycentre: [Int]?
        /// Every world's centre, world order.
        let worlds: [[Int]?]
        /// Both stars' centres, star 1 first.
        let stars: [[Int]?]
        /// The first gauge plate's left margin; null without worlds.
        let gaugeMargin: [Int]?
        /// The first actions bar; null without a budget.
        let firstActionsBar: [Int]?
        /// The first tilt pip; null without a tilt dial.
        let firstTiltPip: [Int]?

        /// Encodes every field; a missing position is written as null rather than left out.
        func encode(to encoder: Encoder) throws {
            var c: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(level, forKey: .level)
            try c.encode(tier, forKey: .tier)
            try c.encode(width, forKey: .width)
            try c.encode(height, forKey: .height)
            try c.encode(quantum, forKey: .quantum)
            try c.encode(tick, forKey: .tick)
            try c.encode(tilt, forKey: .tilt)
            try c.encode(counts, forKey: .counts)
            try c.encode(starValues, forKey: .starValues)
            try c.encode(windows, forKey: .windows)
            try c.encode(colours, forKey: .colours)
            try c.encode(materials, forKey: .materials)
            try c.encode(barycentre, forKey: .barycentre)
            try c.encode(worlds, forKey: .worlds)
            try c.encode(stars, forKey: .stars)
            try c.encode(gaugeMargin, forKey: .gaugeMargin)
            try c.encode(firstActionsBar, forKey: .firstActionsBar)
            try c.encode(firstTiltPip, forKey: .firstTiltPip)
        }
    }

    /// `c` in 8 bits per channel, `[r, g, b]`, each clamped to 0 … 1 and rounded.
    static func colour(_ c: SIMD3<Double>) -> [Int] {
        [byte(c.x), byte(c.y), byte(c.z)]
    }

    /// One channel 0 … 1 as a byte.
    static func byte(_ v: Double) -> Int {
        Int((min(max(v, 0), 1) * 255).rounded())
    }

    /// The palette colour named `name` (one of ``colourNames``); black for an unknown name.
    static func paletteColour(_ name: String) -> SIMD3<Double> {
        for entry in BinaryGardensPalette.all where entry.name == name { return entry.colour }
        return SIMD3(0, 0, 0)
    }

    /// The material table as described: every entry of ``BinaryGardensShaders/materials`` in code order.
    static var materialTable: [MaterialEntry] {
        var table: [MaterialEntry] = []
        for entry in BinaryGardensShaders.materials {
            table.append(MaterialEntry(code: Int(entry.code), name: entry.name, constant: entry.constant))
        }
        return table
    }

    /// The pixel position of `point` at ``width`` × ``height`` with `camera` (the projected view point scaled to
    /// pixels, as the frame checks place it), in 1/``quantum`` pixel; nil when it does not project (behind the eye or
    /// not finite).
    static func position(_ point: SIMD3<Double>, camera: BinaryGardensCamera) -> [Int]? {
        guard let p = BinaryGardensSceneGeometry.project(point, camera: camera) else { return nil }
        let x: Double = (p.x * Double(width) * Double(quantum)).rounded()
        let y: Double = (p.y * Double(height) * Double(quantum)).rounded()
        guard abs(x) < 1e12, abs(y) < 1e12 else { return nil }
        return [Int(x), Int(y)]
    }

    /// The camera of every frame: the authored camera (view orbit at rest) at the frame-check aspect, ``width`` /
    /// ``height``.
    static var camera: BinaryGardensCamera {
        BinaryGardensSceneGeometry.camera(aspect: Double(width) / Double(height))
    }

    /// The elements of `snapshot` drawn in the broken colour: a frozen or scorched world's broken ring and gauge cell,
    /// an unstable world's window bracket pieces (its required tick alone when it has no comfortable tick), a wilted or
    /// bleached world's bloom marker; 0 on a play that has not failed.
    static func brokenCount(_ snapshot: BinaryGardensSceneSnapshot) -> Int {
        typealias G = BinaryGardensSceneGeometry
        var count: Int = 0
        if G.lethalMark(snapshot) != nil { count += 2 }
        if let world = G.unstableWorld(snapshot), snapshot.worlds.indices.contains(world) {
            let pieces: Int = G.windowPieces(snapshot.worlds[world]).count
            count += pieces > 0 ? pieces : 1
        }
        if G.bloomWorld(snapshot) != nil { count += 1 }
        return count
    }

    /// The counts of `snapshot` (clarification Q3).
    static func counts(_ snapshot: BinaryGardensSceneSnapshot) -> Counts {
        typealias G = BinaryGardensSceneGeometry
        var standing: Set<Int> = []
        for ring in snapshot.arrangement.rings where snapshot.ringRadii.indices.contains(ring) {
            standing.insert(ring)
        }
        var worldsByBand: [Int] = [0, 0, 0, 0, 0]
        var cellsByBand: [Int] = [0, 0, 0, 0, 0]
        var shortBrackets: Int = 0
        for (index, world) in snapshot.worlds.enumerated() {
            if let slot = bands.firstIndex(of: snapshot.band(index)) { worldsByBand[slot] += 1 }
            for band in world.bands {
                if let slot = bands.firstIndex(of: band) { cellsByBand[slot] += 1 }
            }
            if world.longestWindow < world.window && !G.windowPieces(world).isEmpty { shortBrackets += 1 }
        }
        let dial: Bool = snapshot.maxTilt > 0
        var luminosityLit: Int = 0
        var luminosityAll: Int = 0
        for star in 0..<2 {
            for pip in G.luminosityPips(star, snapshot) {
                luminosityAll += 1
                if pip.lit { luminosityLit += 1 }
            }
        }
        let tiltLit: Int = dial && (0...snapshot.maxTilt).contains(snapshot.arrangement.tilt) ? 1 : 0
        return Counts(rings: snapshot.ringRadii.count, starRings: standing.count, worlds: snapshot.worlds.count,
                      worldsByBand: worldsByBand, cellsByBand: cellsByBand, shortBrackets: shortBrackets,
                      tiltPipsLit: tiltLit, tiltPips: dial ? snapshot.maxTilt + 1 : 0,
                      luminosityPipsLit: luminosityLit, luminosityPips: luminosityAll,
                      actionsLit: G.litActions(snapshot), actions: max(snapshot.budget, 0),
                      broken: brokenCount(snapshot))
    }

    /// The structured description of `frame`.
    static func describe(_ frame: Frame) throws -> Description {
        typealias G = BinaryGardensSceneGeometry
        let snapshot: BinaryGardensSceneSnapshot = try snapshot(frame)
        let camera: BinaryGardensCamera = camera
        var worlds: [[Int]?] = []
        var windows: [WindowValue] = []
        for (index, world) in snapshot.worlds.enumerated() {
            worlds.append(position(G.worldCentre(index, snapshot), camera: camera))
            windows.append(WindowValue(integral: world.integral, window: world.longestWindow,
                                       start: world.windowStart))
        }
        var stars: [[Int]?] = []
        var starValues: [StarValue] = []
        let arrangement: BinaryGardensArrangement = snapshot.arrangement
        for star in 0..<2 {
            stars.append(position(G.starCentre(star, snapshot), camera: camera))
            let ring: Int = arrangement.rings.indices.contains(star) ? arrangement.rings[star] : -1
            let phase: Int = arrangement.phases.indices.contains(star) ? arrangement.phases[star] : -1
            let luminosity: Int = arrangement.luminosities.indices.contains(star) ? arrangement.luminosities[star] : -1
            starValues.append(StarValue(ring: ring, phase: phase, luminosity: luminosity))
        }
        var colours: [String: [Int]] = [:]
        for entry in BinaryGardensPalette.all { colours[entry.name] = colour(entry.colour) }
        let margin: [Int]? = snapshot.worlds.isEmpty ? nil : position(G.gaugeMargin(0), camera: camera)
        let bar: [Int]? = snapshot.budget > 0 ? position(G.actionsBar(0, snapshot), camera: camera) : nil
        let pip: [Int]? = snapshot.maxTilt > 0 ? position(G.tiltPipCentre(0), camera: camera) : nil
        return Description(name: frame.name, level: frame.level, tier: frame.tier, width: width, height: height,
                           quantum: quantum, tick: snapshot.shownTick, tilt: arrangement.tilt,
                           counts: counts(snapshot), starValues: starValues, windows: windows, colours: colours,
                           materials: materialTable, barycentre: position(SIMD3(0, 0, 0), camera: camera),
                           worlds: worlds, stars: stars, gaugeMargin: margin, firstActionsBar: bar,
                           firstTiltPip: pip)
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
        /// The pinned description.
        let description: Description
        /// The SHA-256 hex of the pinned description.
        let digest: String
    }

    /// The pinned file.
    struct Manifest: Codable, Equatable {
        /// The schema, 1.
        let schema: Int
        /// The entries by frame name.
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

    /// Writes ``manifest()`` to `file` (atomically) only when `environment[writeSwitch]` is `"1"`
    /// (`BINARY_GARDENS_WRITE_GOLDEN=1`); otherwise touches nothing.
    ///
    /// - Returns: whether the file was written.
    /// - Throws: as ``manifest()``; a write failure.
    @discardableResult
    public static func writeIfRequested(
        to file: URL, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Bool {
        guard environment[writeSwitch] == "1" else { return false }
        try manifest().write(to: file, options: [.atomic])
        return true
    }

    /// Compares `frame`'s recomputed description with its entry in the pinned file `pinned`. The pinned digest must be
    /// the digest of the pinned description. Returns nil when the recomputed digest equals it, or when every position
    /// lies within one quantum of the pinned one and every count, value, colour and material entry is equal;
    /// otherwise the first difference in words, naming the frame.
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
        if a.tick != b.tick { return "\(frame): tick \(a.tick), pinned tick \(b.tick)" }
        if a.tilt != b.tilt { return "\(frame): tilt \(a.tilt), pinned tilt \(b.tilt)" }
        let pinnedCounts: [(name: String, value: [Int])] = b.counts.named
        for (index, count) in a.counts.named.enumerated() where count.value != pinnedCounts[index].value {
            return "\(frame): count \(count.name) \(count.value), pinned \(pinnedCounts[index].value)"
        }
        if a.starValues.count != b.starValues.count {
            return "\(frame): \(a.starValues.count) star values, pinned \(b.starValues.count)"
        }
        for index in a.starValues.indices where a.starValues[index] != b.starValues[index] {
            let s: StarValue = a.starValues[index]
            let p: StarValue = b.starValues[index]
            return "\(frame): star \(index) ring \(s.ring) phase \(s.phase) luminosity \(s.luminosity), pinned ring "
                + "\(p.ring) phase \(p.phase) luminosity \(p.luminosity)"
        }
        if a.windows.count != b.windows.count {
            return "\(frame): \(a.windows.count) world windows, pinned \(b.windows.count)"
        }
        for index in a.windows.indices where a.windows[index] != b.windows[index] {
            let w: WindowValue = a.windows[index]
            let p: WindowValue = b.windows[index]
            return "\(frame): world \(index) integral \(w.integral) window \(w.window) from \(w.start), pinned "
                + "integral \(p.integral) window \(p.window) from \(p.start)"
        }
        for name in colourNames where a.colours[name] != b.colours[name] {
            return "\(frame): colour \(name) differs"
        }
        if a.colours.count != b.colours.count || Set(a.colours.keys) != Set(b.colours.keys) {
            return "\(frame): colour set differs"
        }
        if a.materials.count != b.materials.count {
            return "\(frame): \(a.materials.count) materials, pinned \(b.materials.count)"
        }
        for index in a.materials.indices where a.materials[index] != b.materials[index] {
            let m: MaterialEntry = a.materials[index]
            let p: MaterialEntry = b.materials[index]
            return "\(frame): material \(index) is \(m.code) \(m.name) \(m.constant), pinned \(p.code) \(p.name) "
                + p.constant
        }
        if !near(a.barycentre, b.barycentre) {
            return "\(frame): barycentre at \(text(a.barycentre)) eighths, pinned \(text(b.barycentre))"
        }
        if a.worlds.count != b.worlds.count {
            return "\(frame): \(a.worlds.count) world points, pinned \(b.worlds.count)"
        }
        for index in a.worlds.indices where !near(a.worlds[index], b.worlds[index]) {
            return "\(frame): world \(index) at \(text(a.worlds[index])) eighths, pinned " + text(b.worlds[index])
        }
        if a.stars.count != b.stars.count { return "\(frame): \(a.stars.count) star points, pinned \(b.stars.count)" }
        for index in a.stars.indices where !near(a.stars[index], b.stars[index]) {
            return "\(frame): star \(index) at \(text(a.stars[index])) eighths, pinned " + text(b.stars[index])
        }
        if !near(a.gaugeMargin, b.gaugeMargin) {
            return "\(frame): gauge margin at \(text(a.gaugeMargin)) eighths, pinned \(text(b.gaugeMargin))"
        }
        if !near(a.firstActionsBar, b.firstActionsBar) {
            return "\(frame): first actions bar at \(text(a.firstActionsBar)) eighths, pinned "
                + text(b.firstActionsBar)
        }
        if !near(a.firstTiltPip, b.firstTiltPip) {
            return "\(frame): first tilt pip at \(text(a.firstTiltPip)) eighths, pinned \(text(b.firstTiltPip))"
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
