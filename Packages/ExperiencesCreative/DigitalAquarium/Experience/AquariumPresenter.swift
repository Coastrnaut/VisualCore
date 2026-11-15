// AquariumPresenter — feature 068 (A09-P01) T-A09-103 (FR-A09-120, FR-A09-121, FR-A09-123; clarifications 2 and 5;
// research D5; edge cases "very small screens", "Reduce Motion"). Draws Digital Aquarium through the host only (the
// host's context and registry, VisualCore's `PrimitiveRenderer` with a `Camera2D`; no context of its own). The scene
// is code, every frame from the core's habitat document:
//   - Mapping: the 16 × 9 tank (habitat units, y up) is scaled uniformly to fit the canvas and centred; the canvas
//     around it (letterbox) is cleared in the same water colour, so the aquarium fills any canvas. The simulation never
//     sees the canvas: drawing scales, the simulation does not.
//   - Water: one rect over the tank in the habitat's water colour scaled by the lighting (dim 0.6, soft 0.8, bright 1.0).
//   - Gravel: one rect over the band y 0…1 (plants stand on y 1).
//   - Plants: a ribbon is a polyline of 12 points rising to its height, swaying sideways by
//     amplitude × t² × sin(step × 0.05 + x + 1.5 t) (t the height fraction); a fan is five lines spread from its base,
//     their tips swaying the same way. Reduce Motion halves the sway amplitude.
//   - Fish: a closed polygon of 12 outline points from the species shape (teardrop: deep and rounded at the head;
//     slender: long and thin), scaled by the species length, plus a tail triangle in the fin colour, rotated to the
//     heading and mirrored when swimming left so the fish is never upside down.
//   - Decor (feature 069): each decor piece of the document is one polygon in its kind's colour under the lighting, in
//     front of the water, gravel and plants and behind the fish: a rock is an irregular rounded 9-point outline, a shell
//     a 12-point snail spiral opening at its lip; the drawn width is the kind's size × the piece's scale, turned by the
//     piece's rotation about its position. Pieces of kinds missing from the catalog are skipped.
//   - At most 24 fish, 12 plants and 12 decor pieces: 48 fish shapes, 12 plant nodes of up to 5 lines each, 12 decor
//     polygons, the water and the gravel.
// Reduce Motion is presentation only: the core's state and digest never depend on it. No audio.
//
// Feature 069 (A09-P02) T-A09-205 (FR-A09-211; clarification 5; research D5): the swim animation is drawn from the
// state only (the animation phase and the smoothed `turn`; drawing never writes the state). In the fish's local frame
// (nose along +x at x = length/2) with u = 0 at the nose to 1 at the back (u = ½ − x / length, clamped):
//   - body wave: each outline point moves sideways by 0.06 × length × sin(phase − 4u) × u; its frequency grows with
//     speed because the simulation advances the phase by 0.6 × speed / length beats per second;
//   - tail swing: the tail's two tips move sideways by 0.15 × length × sin(phase) (its joint follows the body wave),
//     replacing the Phase 01 angular swing of 0.4 rad;
//   - bend: every point turns about the nose by clamp(turn × 0.12, ±0.35) × u² rad so the back curves to the side the
//     fish turns to (a left turn, positive `turn`, bends the body to the left of the heading); a fish mirrored to swim
//     left draws its local bend with the opposite sign, so the bend always follows the turn in the tank;
//   - Reduce Motion multiplies wave, swing and bend by ½.
//
// Description: "Digital Aquarium: Reef, 7 fish of 2 species (Orange striped fish and Blue fish with yellow tail), 5
// plants, lighting soft, swimming." — habitat name, fish count, species count and names (in order of first appearance),
// plant count, lighting (dim, soft, bright) and swimming or paused.
import Foundation
import SwiftUI
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class AquariumMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The chosen starter habitat's index.
    var habitatIndex = 0
    /// The lighting level (0 dim, 1 soft, 2 bright).
    var lightingLevel = 1
    /// Whether the motion is paused.
    var paused = false
    /// The status line: habitat, fish and plant counts.
    var status = ""
}

/// A failure the presenter injects for tests (`failNextDraw`).
enum AquariumDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}

/// Draws Digital Aquarium and owns its presentation state (the Reduce Motion preference, the scene nodes).
@MainActor
final class AquariumPresenter: ExperiencePresenter {
    /// The tank's width in habitat units.
    nonisolated static let tankWidth = SwimBounds.tankWidth
    /// The tank's height in habitat units.
    nonisolated static let tankHeight = SwimBounds.tankHeight
    /// The top of the gravel band (plants stand on it).
    nonisolated static let gravelTop = HabitatDocument.plantBaseY
    /// The colour factor of each lighting level: dim, soft, bright.
    nonisolated static let lightingFactors = [0.6, 0.8, 1.0]
    /// The spoken name of each lighting level.
    static let lightingNames = ["dim", "soft", "bright"]
    /// The gravel colour at full light.
    nonisolated static let gravelColor = Vec4(0.55, 0.48, 0.36, 1)
    /// The most fish and plants a habitat may hold (clarification 5).
    nonisolated static let maxFish = HabitatDocument.maxFish, maxPlants = HabitatDocument.maxPlants
    /// The number of lines of a fan plant.
    nonisolated static let fanLines = 5
    /// The number of points of a ribbon plant.
    nonisolated static let ribbonPoints = 12
    /// The number of outline points of a fish body.
    nonisolated static let outlinePoints = 12
    /// The sway amplitude of a plant's tip in habitat units (full motion).
    nonisolated static let swayAmplitude = 0.35
    /// The sway's angular rate per simulation step.
    nonisolated static let swayRate = 0.05
    /// The most decor pieces a habitat may hold.
    nonisolated static let maxDecor = HabitatDocument.maxDecor
    /// The body wave's amplitude at the back in body lengths (full motion).
    nonisolated static let bodyWave = 0.06
    /// The phase lag of the body wave from nose to back in radians.
    nonisolated static let waveLag = 4.0
    /// The tail tips' sideways swing in body lengths (full motion).
    nonisolated static let tailSweep = 0.15
    /// The bend per unit of `turn` (rad/s) in radians per second.
    nonisolated static let bendPerTurn = 0.12
    /// The largest bend at the back in radians (full motion).
    nonisolated static let maxBend = 0.35
    /// The radii (fractions of the half width) of a rock's 9 outline points, counter-clockwise from +x.
    nonisolated static let rockRadii = [1.0, 0.86, 0.95, 0.8, 0.92, 0.84, 0.97, 0.82, 0.9]
    /// A rock's height as a fraction of its width.
    nonisolated static let rockAspect = 0.62
    /// The number of outline points of a shell.
    nonisolated static let shellPoints = 12
    /// The inner radius of a shell's spiral as a fraction of its outer radius.
    nonisolated static let shellInner = 0.35
    /// The line width of plants in habitat units.
    nonisolated static let plantWidth = 0.14

    let experienceID: ExperienceID
    let mirror = AquariumMirror()
    /// With Reduce Motion on, the plant sway and the swim animation are halved (presentation only).
    let reduceMotion: Bool

    /// Set by a test to make the next draw throw `AquariumDrawError.injected` (the seam clears itself).
    var failNextDraw = false
    /// Whether the scene is set up.
    private(set) var isLive = false
    /// The last core drawn or described.
    private(set) var lastCore: AquariumCore?
    /// The scale of the last frame (pixels per habitat unit).
    private(set) var lastScale = 0.0
    /// The number of fish and plant nodes drawn in the last frame.
    private(set) var lastFishDrawn = 0, lastPlantsDrawn = 0
    /// The number of decor pieces drawn in the last frame.
    private(set) var lastDecorDrawn = 0
    /// The motion factor (1 or ½) of the plant sway and the swim animation in the last frame.
    private(set) var lastSwayFactor = 1.0

    private let clear = ClearColorScene(red: 0, green: 0, blue: 0)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "aquarium")
    private let water = SceneNode(id: "water", z: 0)
    private let gravel = SceneNode(id: "gravel", z: 1)
    private var plantNodes: [[SceneNode]] = []
    private var decorNodes: [SceneNode] = []
    private var tailNodes: [SceneNode] = []
    private var bodyNodes: [SceneNode] = []

    init(experienceID: ExperienceID, reduceMotion: Bool = false) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
        root.add(water)
        root.add(gravel)
        for plant in 0..<Self.maxPlants {
            var lines: [SceneNode] = []
            for line in 0..<Self.fanLines {
                let node = SceneNode(id: "p\(plant).\(line)", z: 2)
                root.add(node)
                lines.append(node)
            }
            plantNodes.append(lines)
        }
        for piece in 0..<Self.maxDecor {
            let node = SceneNode(id: "d\(piece)", z: 3)
            root.add(node)
            decorNodes.append(node)
        }
        for fish in 0..<Self.maxFish {
            let tail = SceneNode(id: "t\(fish)", z: 4)
            let body = SceneNode(id: "f\(fish)", z: 5)
            root.add(tail)
            root.add(body)
            tailNodes.append(tail)
            bodyNodes.append(body)
        }
    }

    /// The factor of the plant sway and the swim animation: ½ with Reduce Motion, 1 otherwise.
    var motionFactor: Double { reduceMotion ? 0.5 : 1 }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
    }

    func draw(_ core: AquariumCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw AquariumDrawError.injected
        }
        sync(core)
        let waterColor = Self.waterColor(core.document)
        clear.red = Float(waterColor.x)
        clear.green = Float(waterColor.y)
        clear.blue = Float(waterColor.z)
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        layOut(core, width: width, height: height)
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
    }

    func teardown(_ context: RenderContext) {
        isLive = false
        primitives?.release()
        primitives = nil
    }

    // MARK: Drawing

    /// The lighting factor of `level` (0.6, 0.8 or 1.0; soft for an unknown level).
    nonisolated static func lightingFactor(_ level: Int) -> Double {
        lightingFactors.indices.contains(level) ? lightingFactors[level] : lightingFactors[1]
    }

    /// `color` scaled by the lighting factor of `level` (alpha kept).
    nonisolated static func lit(_ color: RGBA, level: Int) -> Vec4 {
        let f = lightingFactor(level)
        return Vec4(color.r * f, color.g * f, color.b * f, color.a)
    }

    /// The water colour of `document` under its lighting.
    nonisolated static func waterColor(_ document: HabitatDocument) -> Vec4 {
        lit(document.waterColor, level: document.lighting)
    }

    /// The uniform scale (pixels per habitat unit) that fits the tank into `width` × `height` pixels.
    nonisolated static func scale(width: Double, height: Double) -> Double {
        min(width / tankWidth, height / tankHeight)
    }

    /// The world point (pixels from the canvas centre, y up) of the habitat point `p` at `scale`.
    nonisolated static func world(_ p: Vec2, scale: Double) -> Vec2 {
        Vec2((p.x - tankWidth / 2) * scale, (p.y - tankHeight / 2) * scale)
    }

    /// The 12 outline points of a fish body of `shape` and `length`, nose along +x, centred on the origin.
    nonisolated static func outline(_ shape: FishShape, length: Double) -> [Vec2] {
        let depth = shape == .teardrop ? 0.46 : 0.22
        return (0..<outlinePoints).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(outlinePoints)
            let c = cos(angle), s = sin(angle)
            // Deeper towards the head (c > 0), tapering towards the tail.
            let taper = shape == .teardrop ? 0.78 + 0.22 * c : 0.85 + 0.15 * c
            return Vec2(c * length / 2, s * depth * length / 2 * taper)
        }
    }

    /// The body fraction u of the fish-local x of a fish of `length`: 0 at the nose (x = length/2), 1 at the back
    /// (x = −length/2), clamped to 0…1 (the tail behind the body counts as the back).
    nonisolated static func bodyFraction(_ x: Double, length: Double) -> Double {
        guard length > 0 else { return 0 }
        return min(max(0.5 - x / length, 0), 1)
    }

    /// The bend at the back in radians for `turn` (rad/s): clamp(turn × 0.12, ±0.35) × `factor`; 0 for a non-finite
    /// turn.
    nonisolated static func bendAngle(turn: Double, factor: Double) -> Double {
        guard turn.isFinite else { return 0 }
        return min(max(turn * bendPerTurn, -maxBend), maxBend) * factor
    }

    /// The sideways body-wave displacement at body fraction `u`: 0.06 × length × sin(phase − 4u) × u × `factor`.
    nonisolated static func waveOffset(u: Double, length: Double, phase: Double, factor: Double) -> Double {
        bodyWave * length * sin(phase - waveLag * u) * u * factor
    }

    /// `p` (fish-local) turned about the nose (length/2, 0) by −`bend` × u², so a positive bend moves the back to +y
    /// (the fish's left in the unmirrored frame).
    nonisolated static func bent(_ p: Vec2, u: Double, length: Double, bend: Double) -> Vec2 {
        let nose = Vec2(length / 2, 0)
        let angle = -bend * u * u
        let d = p - nose
        let c = cos(angle), s = sin(angle)
        return nose + Vec2(d.x * c - d.y * s, d.x * s + d.y * c)
    }

    /// The 12 animated outline points of a fish body of `shape` and `length` (fish-local, nose along +x): the
    /// ``outline(_:length:)`` with the body wave of `phase` and the bend of `turn` (rad/s, positive = left), both
    /// scaled by `factor` (1, ½ with Reduce Motion, 0 for the straight outline).
    nonisolated static func animatedOutline(_ shape: FishShape, length: Double, phase: Double, turn: Double,
                                            factor: Double) -> [Vec2] {
        let bend = bendAngle(turn: turn, factor: factor)
        return outline(shape, length: length).map { p in
            let u = bodyFraction(p.x, length: length)
            let waved = Vec2(p.x, p.y + waveOffset(u: u, length: length, phase: phase, factor: factor))
            return bent(waved, u: u, length: length, bend: bend)
        }
    }

    /// The animated tail triangle of a fish of `length` (fish-local, nose along +x): the joint at x = −0.42 length
    /// follows the body wave, the two tips swing sideways by 0.15 × length × sin(`phase`), and all three follow the
    /// bend of `turn`; everything scaled by `factor`.
    nonisolated static func animatedTail(length: Double, phase: Double, turn: Double, factor: Double) -> [Vec2] {
        let bend = bendAngle(turn: turn, factor: factor)
        let jointX = -length * 0.42, tipX = jointX - length * 0.32
        let joint = waveOffset(u: bodyFraction(jointX, length: length), length: length, phase: phase, factor: factor)
        let sweep = tailSweep * length * sin(phase) * factor
        let points = [Vec2(jointX, joint), Vec2(tipX, length * 0.2 + sweep), Vec2(tipX, -length * 0.2 + sweep)]
        return points.map { bent($0, u: bodyFraction($0.x, length: length), length: length, bend: bend) }
    }

    /// The body and tail polygons of `fish` (habitat units) for a species of `shape` and `length`: animated from the
    /// fish's phase and turn by `factor`, mirrored when it swims left (with the local bend negated, so the body still
    /// bends toward the turn in the tank), rotated to its heading and moved to its position.
    nonisolated static func fishPolygons(_ fish: FishAgent, shape: FishShape, length: Double,
                                         factor: Double) -> (body: [Vec2], tail: [Vec2]) {
        let mirrored = fish.velocity.x < 0
        let turn = mirrored ? -fish.turn : fish.turn
        let body = animatedOutline(shape, length: length, phase: fish.animationPhase, turn: turn, factor: factor)
        let tail = animatedTail(length: length, phase: fish.animationPhase, turn: turn, factor: factor)
        return (placed(body, position: fish.position, heading: fish.heading, mirrored: mirrored),
                placed(tail, position: fish.position, heading: fish.heading, mirrored: mirrored))
    }

    /// The outline of a decor piece of `shape` (centred on the origin, habitat units) whose drawn width is
    /// `size` × `scale`, turned counter-clockwise by `rotation`: a rock is an irregular rounded 9-point outline
    /// (``rockRadii``, height ``rockAspect`` of the width); a shell a 12-point spiral whose radius grows from
    /// ``shellInner`` to 1 of its outer radius over one turn, closed across its lip.
    nonisolated static func decorOutline(_ shape: DecorShape, size: Double, rotation: Double, scale: Double) -> [Vec2] {
        let width = size * scale
        let local: [Vec2]
        switch shape {
        case .rock:
            local = rockRadii.indices.map { i in
                let r = rockRadii[i]
                let angle = 2 * Double.pi * Double(i) / Double(rockRadii.count)
                return Vec2(cos(angle) * r * width / 2, sin(angle) * r * width / 2 * rockAspect)
            }
        case .shell:
            // The spiral spans x from −r(π) to r(2π) = R, so its width is R × (1 + r(π)/R).
            let outer = width / (1 + shellInner + (1 - shellInner) / 2)
            local = (0..<shellPoints).map { i in
                let t = Double(i) / Double(shellPoints - 1)
                let angle = 2 * Double.pi * t
                let r = outer * (shellInner + (1 - shellInner) * t)
                return Vec2(cos(angle) * r, sin(angle) * r)
            }
        }
        let c = cos(rotation), s = sin(rotation)
        return local.map { p in Vec2(p.x * c - p.y * s, p.x * s + p.y * c) }
    }

    /// `points` (fish-local, nose along +x) mirrored vertically when `mirrored`, rotated by `heading` and moved to
    /// `position`, all in habitat units.
    nonisolated static func placed(_ points: [Vec2], position: Vec2, heading: Double, mirrored: Bool) -> [Vec2] {
        let c = cos(heading), s = sin(heading)
        return points.map { p in
            let q = mirrored ? Vec2(p.x, -p.y) : p
            return position + Vec2(q.x * c - q.y * s, q.x * s + q.y * c)
        }
    }

    /// The sideways sway of a plant at height fraction `t` (0 at the base, 1 at the tip) standing at `x` at `step`.
    nonisolated static func sway(t: Double, x: Double, step: Int, factor: Double) -> Double {
        swayAmplitude * factor * t * t * sin(Double(step) * swayRate + x + 1.5 * t)
    }

    /// Places every node for a canvas of `width` × `height` pixels (world = pixels from the centre, y up).
    private func layOut(_ core: AquariumCore, width: Double, height: Double) {
        let document = core.document
        let catalog = AquariumCore.catalog
        let level = document.lighting
        let s = Self.scale(width: width, height: height)
        lastScale = s
        let factor = motionFactor
        lastSwayFactor = factor
        func world(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }

        water.primitive = .rect(Vec2(Self.tankWidth * s, Self.tankHeight * s))
        water.position = world(Vec2(Self.tankWidth / 2, Self.tankHeight / 2))
        water.color = Self.waterColor(document)
        gravel.primitive = .rect(Vec2(Self.tankWidth * s, Self.gravelTop * s))
        gravel.position = world(Vec2(Self.tankWidth / 2, Self.gravelTop / 2))
        let f = Self.lightingFactor(level)
        gravel.color = Vec4(Self.gravelColor.x * f, Self.gravelColor.y * f, Self.gravelColor.z * f, 1)

        var plantsDrawn = 0
        for (index, lines) in plantNodes.enumerated() {
            for node in lines { node.primitive = nil }
            guard index < document.plants.count, let kind = catalog.plant(id: document.plants[index].kindId) else {
                continue
            }
            let x = document.plants[index].x
            let color = Self.lit(kind.color, level: level)
            let width = Self.plantWidth * s
            switch kind.shape {
            case .ribbon:
                let points = (0..<Self.ribbonPoints).map { i -> Vec2 in
                    let t = Double(i) / Double(Self.ribbonPoints - 1)
                    let p = Vec2(x + Self.sway(t: t, x: x, step: core.step, factor: factor),
                                 Self.gravelTop + t * kind.height)
                    return world(p)
                }
                lines[0].primitive = .polyline(points, width: width)
                lines[0].color = color
            case .fan:
                let base = Vec2(x, Self.gravelTop)
                for (line, node) in lines.enumerated() {
                    let spread = (Double(line) / Double(Self.fanLines - 1) - 0.5) * 1.1
                    let tip = Vec2(x + sin(spread) * kind.height * 0.8
                                       + Self.sway(t: 1, x: x + Double(line) * 0.3, step: core.step, factor: factor),
                                   Self.gravelTop + cos(spread) * kind.height)
                    node.primitive = .line(world(base), world(tip), width: width)
                    node.color = color
                }
            }
            plantsDrawn += 1
        }
        lastPlantsDrawn = plantsDrawn

        var decorDrawn = 0
        for (index, node) in decorNodes.enumerated() {
            node.primitive = nil
            guard index < document.decor.count, let kind = catalog.decor(id: document.decor[index].kindId) else {
                continue
            }
            let piece = document.decor[index]
            let points = Self.decorOutline(kind.shape, size: kind.size, rotation: piece.rotation, scale: piece.scale)
            node.primitive = .polygon(points.map { world(piece.position + $0) })
            node.color = Self.lit(kind.color, level: level)
            decorDrawn += 1
        }
        lastDecorDrawn = decorDrawn

        var fishDrawn = 0
        for index in 0..<Self.maxFish {
            let body = bodyNodes[index], tail = tailNodes[index]
            body.primitive = nil
            tail.primitive = nil
            guard index < document.fish.count, let species = catalog.species(id: document.fish[index].speciesId) else {
                continue
            }
            let fish = document.fish[index]
            let shapes = Self.fishPolygons(fish, shape: species.shape, length: species.length, factor: factor)
            body.primitive = .polygon(shapes.body.map(world))
            body.color = Self.lit(species.bodyColor, level: level)
            tail.primitive = .polygon(shapes.tail.map(world))
            tail.color = Self.lit(species.finColor, level: level)
            fishDrawn += 1
        }
        lastFishDrawn = fishDrawn
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: AquariumCore) {
        lastCore = core
        let document = core.document
        if !mirror.ready { mirror.ready = true }
        if mirror.habitatIndex != document.habitatIndex { mirror.habitatIndex = document.habitatIndex }
        if mirror.lightingLevel != document.lighting { mirror.lightingLevel = document.lighting }
        if mirror.paused != core.paused { mirror.paused = core.paused }
        let status = "\(Self.habitatName(document)), \(Self.fishWords(document.fish.count)), "
            + "\(Self.plantWords(document.plants.count)), \(core.paused ? "paused" : "swimming")"
        if mirror.status != status { mirror.status = status }
    }

    /// The name of `document`'s starter habitat ("Aquarium" for an unknown index).
    static func habitatName(_ document: HabitatDocument) -> String {
        let habitats = AquariumCore.catalog.habitats
        return habitats.indices.contains(document.habitatIndex) ? habitats[document.habitatIndex].name : "Aquarium"
    }

    /// The names of the species in `document`, in order of first appearance.
    static func speciesNames(_ document: HabitatDocument) -> [String] {
        var ids: [String] = []
        for fish in document.fish where !ids.contains(fish.speciesId) { ids.append(fish.speciesId) }
        return ids.map { AquariumCore.catalog.species(id: $0)?.name ?? $0 }
    }

    /// "1 fish" or "7 fish".
    static func fishWords(_ count: Int) -> String { "\(count) fish" }

    /// "1 plant" or "5 plants".
    static func plantWords(_ count: Int) -> String { count == 1 ? "1 plant" : "\(count) plants" }

    /// The spoken name of the lighting level `level`.
    static func lightingName(_ level: Int) -> String {
        lightingNames.indices.contains(level) ? lightingNames[level] : lightingNames[1]
    }

    /// The names joined with commas and "and": "A", "A and B", "A, B and C".
    static func joined(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// "Digital Aquarium: Reef, 7 fish of 2 species (Orange striped fish and Blue fish with yellow tail), 5 plants,
    /// lighting soft, swimming."
    func describe(_ core: AquariumCore) -> String {
        sync(core)
        let document = core.document
        let names = Self.speciesNames(document)
        let species = names.count == 1 ? "1 species" : "\(names.count) species"
        return "Digital Aquarium: \(Self.habitatName(document)), \(Self.fishWords(document.fish.count)) of \(species) "
            + "(\(Self.joined(names))), \(Self.plantWords(document.plants.count)), "
            + "lighting \(Self.lightingName(document.lighting)), \(core.paused ? "paused" : "swimming")."
    }

    /// One water probe at the top centre of the canvas (above the swim bounds, where no plant reaches), expecting the
    /// colour class of the lit water; none when the lit water lies within 4 of 255 of a class threshold.
    func probes(_ core: AquariumCore) -> [FrameProbe] {
        let color = Self.waterColor(core.document)
        guard let expected = Self.colorClass(red: color.x, green: color.y, blue: color.z) else { return [] }
        return [FrameProbe(name: "water", x: 0.5, y: 0.01, expected: expected)].compactMap { $0 }
    }

    /// The `FrameColorClass` raw value of a colour (0…1 channels) by the frame checks' rules, nil when a channel
    /// difference or the luma lies within 4 of 255 of a threshold (8-bit rounding could change the class).
    nonisolated static func colorClass(red: Double, green: Double, blue: Double) -> String? {
        let r = red * 255, g = green * 255, b = blue * 255
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let margin = 4.0
        let checks = [luma - 40, luma - 215, r - g - 30, r - b - 30, g - r - 30, g - b - 30, b - r - 30, b - g - 30,
                      max(r, g, b) - min(r, g, b) - 30]
        guard checks.allSatisfy({ abs($0) > margin }) else { return nil }
        if luma < 40 { return FrameColorClass.dark.rawValue }
        if luma > 215, max(r, g, b) - min(r, g, b) < 30 { return FrameColorClass.light.rawValue }
        if r - g >= 30, r - b >= 30 { return FrameColorClass.red.rawValue }
        if g - r >= 30, g - b >= 30 { return FrameColorClass.green.rawValue }
        if b - r >= 30, b - g >= 30 { return FrameColorClass.blue.rawValue }
        return FrameColorClass.other.rawValue
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AquariumControls(port: port, mirror: mirror))
    }

    /// Every action has a native control.
    var nativeActions: Set<String> { Set(AquariumCore.actionIDs) }
}
