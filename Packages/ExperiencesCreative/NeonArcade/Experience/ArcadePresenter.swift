// ArcadePresenter — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121, FR-A10-122; clarifications 1, 4 and 5;
// edge cases "very small screens", "Reduce Motion"). Draws Neon Dodge through the host only (the host's context and
// registry, VisualCore's `PrimitiveRenderer` with a `Camera2D`; no context of its own). The scene is code, rebuilt
// every frame from the core's run, which the presenter only reads:
//   - Mapping: the 9 × 16 field (game units, y up) is scaled uniformly to fit the canvas and centred; the canvas is
//     cleared in a near-black letterbox colour, and four letterbox masks above everything else hide whatever lies
//     outside the field (objects entering above or leaving below). The simulation never sees the canvas.
//   - Field: one dark rect (#07061A); seven faint horizontal lines drift down over the band y 2…16 at 0.6 units/s of
//     game time (the step count), so a paused run holds still.
//   - Objects at their rule sizes: a circle object (spike ball, glow orb) is one circle of its radius; a bar is a
//     capsule — a line 2 × radius wide between its two segment ends plus a circle of its radius at each end. Each
//     object has a glow behind it (a circle, or a line for a bar, 1.6 × its radius) whose alpha pulses as
//     0.35 + 0.15 × sin(step × 0.08). Colours come from the catalog item (fallbacks for an unknown item).
//   - Player: a glow, a ring (a closed polyline of 33 points) of radius equal to the hit radius 0.4 and a chevron
//     pointing up inside it; while invulnerable the ring and chevron blink (dim every other 8 steps). Drawing only.
//   - Score and lives: the score in seven-segment digits (lines) at the top left of the field, the lives as three
//     small circles at the top right (lost lives faint). Paused: two bars in the middle; over: a dark shade over the
//     field and a cross in the hazard colour.
//   - Waves (feature 076, A10-P02, T-A10-203; FR-A10-220; clarification 5): five dim lane guides — thin vertical lines
//     (0.03 units, faint cyan at alpha 0.07) at the lane centres `Lanes.centres` from y 2 (above the player's band, keeping the
//     bottom-centre frame probe on plain field) to the top of the field, drawn under the glows, objects, player and HUD so they never hide or resize a collision shape — and the
//     wave number in the same seven-segment digits beside the score (from x 4.6, at most three digits, in cyan). The
//     spoken description names the wave ("wave 3"). Rule sizes are unchanged.
// Reduce Motion halves the glow pulse amplitude (0.15 → 0.075) and the background drift speed (0.6 → 0.3 units/s);
// the game itself — and so the core's state and digest — never depends on it. Nothing flashes. No audio.
// The canvas drag goes through `ArcadeGestures` (`run.steer`); every action also has a native control.
import Foundation
import SwiftUI
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class ArcadeMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The score.
    var score = 0
    /// The lives left.
    var lives = GameRun.startLives
    /// Whether the run is paused.
    var paused = false
    /// Whether the run is over.
    var over = false
    /// The held steering value, −1…1.
    var steering = 0.0
    /// The status line: score, lives and playing, paused or over.
    var status = ""
}

/// A failure the presenter injects for tests (`failNextDraw`).
enum ArcadeDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}

/// Draws Neon Arcade and owns its presentation state (the Reduce Motion preference, the scene nodes, the gesture).
@MainActor
final class ArcadePresenter: ExperiencePresenter {
    /// The field's width in game units.
    nonisolated static let fieldWidth = GameRun.fieldWidth
    /// The field's height in game units.
    nonisolated static let fieldHeight = GameRun.fieldHeight
    /// The clear colour around the field.
    nonisolated static let letterboxColor = Vec4(0.008, 0.008, 0.02, 1)
    /// The field colour (#07061A).
    nonisolated static let fieldColor = Vec4(0.027, 0.024, 0.102, 1)
    /// The colour of the drifting background lines: faint cyan.
    nonisolated static let driftColor = Vec4(0.13, 0.9, 1.0, 0.08)
    /// The number of drifting background lines.
    nonisolated static let driftLines = 7
    /// The spacing of the drifting lines in game units.
    nonisolated static let driftSpacing = 2.0
    /// The lowest y of a drifting line (the band below, with the player, stays plain).
    nonisolated static let driftBottom = 2.0
    /// The drift speed in game units per second at full motion.
    nonisolated static let driftSpeed = 0.6
    /// The glow alpha around which the pulse swings.
    nonisolated static let glowBase = 0.35
    /// The glow pulse amplitude (alpha) at full motion.
    nonisolated static let glowPulse = 0.15
    /// The pulse's angular rate per simulation step.
    nonisolated static let pulseRate = 0.08
    /// A glow's radius as a multiple of its object's radius.
    nonisolated static let glowScale = 1.6
    /// The player ring's line width in game units.
    nonisolated static let ringWidth = 0.07
    /// The number of points of the player ring (closed: the last equals the first).
    nonisolated static let ringPoints = 33
    /// The chevron inside the player ring, relative to its centre in game units, pointing up (star-shaped from the
    /// tip, so any polygon fill draws it).
    nonisolated static let chevron = [Vec2(0, 0.26), Vec2(0.22, -0.14), Vec2(0, -0.03), Vec2(-0.22, -0.14)]
    /// The invulnerability blink: the player dims every other `blinkSteps` steps to `blinkAlpha`.
    nonisolated static let blinkSteps = 8, blinkAlpha = 0.35
    /// The most digits of the score (9,999,999).
    nonisolated static let maxDigits = 7
    /// A digit's width and height in game units.
    nonisolated static let digitWidth = 0.34, digitHeight = 0.6
    /// The distance from one digit to the next in game units.
    nonisolated static let digitAdvance = 0.48
    /// The top-left corner of the first digit in game units.
    nonisolated static let digitOrigin = Vec2(0.35, 15.65)
    /// The width of a digit's segment lines in game units.
    nonisolated static let segmentWidth = 0.08
    /// The seven segments a…g lit for each digit 0…9 (a top, b top right, c bottom right, d bottom, e bottom left,
    /// f top left, g middle).
    nonisolated static let segmentTable: [[Int]] = [
        [0, 1, 2, 3, 4, 5], [1, 2], [0, 1, 3, 4, 6], [0, 1, 2, 3, 6], [1, 2, 5, 6],
        [0, 2, 3, 5, 6], [0, 2, 3, 4, 5, 6], [0, 1, 2], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 5, 6],
    ]
    /// The centre of the first life marker, the spacing to the next (leftwards) and the marker radius, game units.
    nonisolated static let livesOrigin = Vec2(8.6, 15.35), livesSpacing = 0.45, lifeRadius = 0.17
    /// The colour of the lane guides: faint cyan.
    nonisolated static let laneColor = Vec4(0.13, 0.9, 1.0, 0.07)
    /// The width of a lane guide in game units.
    nonisolated static let laneWidth = 0.03
    /// The most digits of the wave number (999).
    nonisolated static let maxWaveDigits = 3
    /// The top-left corner of the wave number's first digit in game units (beside the score's seven digits).
    nonisolated static let waveOrigin = Vec2(4.6, 15.65)
    /// The colour of the wave digits.
    nonisolated static let waveColor = Vec4(0.13, 0.9, 1.0, 0.9)
    /// The colour of the score digits.
    nonisolated static let hudColor = Vec4(0.85, 0.98, 1.0, 1)
    /// The alpha of a lost life's marker.
    nonisolated static let lostLifeAlpha = 0.2
    /// The pause bars' colour.
    nonisolated static let pauseColor = Vec4(0.9, 0.95, 1.0, 0.8)
    /// The shade over the field once the run is over.
    nonisolated static let overShade = Vec4(0, 0, 0, 0.45)
    /// The fallback colours of an object whose item is not in the catalog.
    nonisolated static let fallbackHazard = Vec4(1.0, 0.2, 0.45, 1), fallbackOrb = Vec4(0.75, 1.0, 0.3, 1)
    /// The z of the field, the drift lines, the lane guides, the glows, the objects, the player, the HUD, the pause
    /// and over marks and the letterbox masks.
    nonisolated static let fieldZ = 0, driftZ = 1, laneZ = 1, glowZ = 2, objectZ = 3, playerZ = 4, hudZ = 6, stateZ = 7,
                           maskZ = 9
    /// The field point (game units) near the bottom centre where the frame probe is taken when it lies in the field.
    nonisolated static let probeMargin = 0.35

    let experienceID: ExperienceID
    let mirror = ArcadeMirror()
    /// With Reduce Motion on, the glow pulse and the background drift are halved (presentation only).
    let reduceMotion: Bool

    /// Set by a test to make the next draw throw `ArcadeDrawError.injected` (the seam clears itself).
    var failNextDraw = false
    /// Whether the scene is set up.
    private(set) var isLive = false
    /// The last core drawn or described.
    private(set) var lastCore: ArcadeCore?
    /// The scale of the last frame (pixels per game unit) and its canvas size in pixels.
    private(set) var lastScale = 0.0, lastCanvas = Vec2(0, 0)
    /// The number of falling objects drawn in the last frame.
    private(set) var lastObjectsDrawn = 0
    /// The score text and the number of lit lives of the last frame.
    private(set) var lastScoreText = "", lastLivesLit = 0
    /// The wave text of the last frame.
    private(set) var lastWaveText = ""
    /// The state mark of the last frame: "none", "paused" (two bars) or "over" (shade and cross).
    private(set) var lastStateMark = "none"
    /// The glow pulse amplitude and the drift speed the last frame was drawn with.
    private(set) var lastPulseAmount = 0.0, lastDriftAmount = 0.0
    /// The canvas gesture (a drag steers).
    private var gestures = ArcadeGestures()
    /// The port of the last canvas pointer event: a held drag keeps steering through it as the player moves
    /// (T-A10-115).
    private var followPort: ExperienceActionPort?

    private let clear = ClearColorScene(red: 0, green: 0, blue: 0)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "arcade")
    /// The field rectangle.
    let field = SceneNode(id: "field", z: ArcadePresenter.fieldZ)
    /// The drifting background lines.
    private(set) var driftNodes: [SceneNode] = []
    /// The five lane guides.
    private(set) var laneNodes: [SceneNode] = []
    /// The glow, body and two capsule end nodes of each object slot.
    private(set) var glowNodes: [SceneNode] = [], bodyNodes: [SceneNode] = []
    private var capNodes: [(SceneNode, SceneNode)] = []
    /// The player's glow, ring and chevron.
    let playerGlow = SceneNode(id: "player.glow", z: ArcadePresenter.glowZ)
    let playerRing = SceneNode(id: "player.ring", z: ArcadePresenter.playerZ)
    let playerChevron = SceneNode(id: "player.chevron", z: ArcadePresenter.playerZ)
    /// The seven segment nodes of each score digit.
    private var digitNodes: [[SceneNode]] = []
    /// The seven segment nodes of each wave digit.
    private(set) var waveDigitNodes: [[SceneNode]] = []
    /// The life markers.
    private(set) var lifeNodes: [SceneNode] = []
    private var pauseNodes: [SceneNode] = []
    private let shade = SceneNode(id: "over.shade", z: ArcadePresenter.stateZ)
    private var crossNodes: [SceneNode] = []
    private var maskNodes: [SceneNode] = []

    /// A presenter.
    /// - Parameters:
    ///   - experienceID: The experience's id.
    ///   - reduceMotion: Halves the glow pulse and the background drift (presentation only).
    init(experienceID: ExperienceID, reduceMotion: Bool = false) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
        root.add(field)
        for index in 0..<Self.driftLines {
            let node = SceneNode(id: "drift\(index)", z: Self.driftZ)
            root.add(node)
            driftNodes.append(node)
        }
        for lane in 0..<Lanes.count {
            let node = SceneNode(id: "lane\(lane)", z: Self.laneZ)
            root.add(node)
            laneNodes.append(node)
        }
        for slot in 0..<GameRun.maxObjects {
            let glow = SceneNode(id: "o\(slot).glow", z: Self.glowZ)
            let body = SceneNode(id: "o\(slot)", z: Self.objectZ)
            let capA = SceneNode(id: "o\(slot).a", z: Self.objectZ)
            let capB = SceneNode(id: "o\(slot).b", z: Self.objectZ)
            for node in [glow, body, capA, capB] { root.add(node) }
            glowNodes.append(glow)
            bodyNodes.append(body)
            capNodes.append((capA, capB))
        }
        root.add(playerGlow)
        root.add(playerRing)
        root.add(playerChevron)
        for digit in 0..<Self.maxDigits {
            var segments: [SceneNode] = []
            for segment in 0..<7 {
                let node = SceneNode(id: "digit\(digit).\(segment)", z: Self.hudZ)
                root.add(node)
                segments.append(node)
            }
            digitNodes.append(segments)
        }
        for digit in 0..<Self.maxWaveDigits {
            var segments: [SceneNode] = []
            for segment in 0..<7 {
                let node = SceneNode(id: "wave\(digit).\(segment)", z: Self.hudZ)
                root.add(node)
                segments.append(node)
            }
            waveDigitNodes.append(segments)
        }
        for life in 0..<GameRun.startLives {
            let node = SceneNode(id: "life\(life)", z: Self.hudZ)
            root.add(node)
            lifeNodes.append(node)
        }
        for bar in 0..<2 {
            let node = SceneNode(id: "pause\(bar)", z: Self.stateZ)
            root.add(node)
            pauseNodes.append(node)
        }
        root.add(shade)
        for line in 0..<2 {
            let node = SceneNode(id: "over\(line)", z: Self.stateZ)
            root.add(node)
            crossNodes.append(node)
        }
        for side in 0..<4 {
            let node = SceneNode(id: "mask\(side)", z: Self.maskZ)
            root.add(node)
            maskNodes.append(node)
        }
    }

    /// The factor of the glow pulse and the background drift: ½ with Reduce Motion, 1 otherwise.
    var motionFactor: Double { reduceMotion ? 0.5 : 1 }
    /// The glow pulse amplitude this presenter draws with (0.15, or 0.075 with Reduce Motion).
    var pulseAmount: Double { Self.glowPulse * motionFactor }
    /// The background drift speed in game units per second this presenter draws with (0.6, or 0.3 with Reduce Motion).
    var driftAmount: Double { Self.driftSpeed * motionFactor }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
    }

    func resize(_ context: RenderContext) {}

    func draw(_ core: ArcadeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw ArcadeDrawError.injected
        }
        sync(core)
        clear.red = Float(Self.letterboxColor.x)
        clear.green = Float(Self.letterboxColor.y)
        clear.blue = Float(Self.letterboxColor.z)
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        layOut(core, width: width, height: height)
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        try primitives?.draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(width, height), scale: 1))
        // T-A10-115: a finger held still keeps steering by its offset from the drawn player (an action at the next
        // step, recorded like any other; the drawing itself changes nothing).
        if let port = followPort {
            for action in gestures.follow(playerX: core.run.player.x) { _ = port.send(action.control, action.values) }
        }
    }

    func teardown(_ context: RenderContext) {
        isLive = false
        gestures.reset()
        followPort = nil
        primitives?.release()
        primitives = nil
    }

    // MARK: Geometry

    /// The uniform scale (pixels per game unit) that fits the field into `width` × `height` pixels.
    nonisolated static func scale(width: Double, height: Double) -> Double {
        min(width / fieldWidth, height / fieldHeight)
    }

    /// The world point (pixels from the canvas centre, y up) of the field point `p` at `scale`.
    nonisolated static func world(_ p: Vec2, scale: Double) -> Vec2 {
        Vec2((p.x - fieldWidth / 2) * scale, (p.y - fieldHeight / 2) * scale)
    }

    /// The glow alpha at `step` with pulse amplitude `amount`: 0.35 + `amount` × sin(step × 0.08).
    nonisolated static func glowAlpha(step: Int, amount: Double) -> Double {
        glowBase + amount * sin(Double(step) * pulseRate)
    }

    /// How far the background lines have drifted down at `step` with drift speed `speed` (units per second of game
    /// time), modulo the line spacing.
    nonisolated static func driftOffset(step: Int, speed: Double) -> Double {
        let travelled = Double(step) * GameSimulation.step * speed
        let offset = travelled.truncatingRemainder(dividingBy: driftSpacing)
        return offset.isFinite ? offset : 0
    }

    /// The y of background line `index` drifted by `offset`: it starts at the top (16) and wraps inside the band
    /// 2…16.
    nonisolated static func driftLineY(index: Int, offset: Double) -> Double {
        let band = fieldHeight - driftBottom
        return fieldHeight - (Double(index) * driftSpacing + offset).truncatingRemainder(dividingBy: band)
    }

    /// The closed ring of ``ringPoints`` points of `radius` around `center` (game units).
    nonisolated static func ring(center: Vec2, radius: Double) -> [Vec2] {
        (0..<ringPoints).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints - 1)
            return center + Vec2(cos(angle) * radius, sin(angle) * radius)
        }
    }

    /// The two ends of segment `segment` (0…6 = a…g) of a digit whose top-left corner is `origin` (game units, y up).
    nonisolated static func segmentEnds(_ segment: Int, origin: Vec2) -> (Vec2, Vec2) {
        let w = digitWidth, h = digitHeight
        let topLeft = origin, topRight = origin + Vec2(w, 0)
        let midLeft = origin + Vec2(0, -h / 2), midRight = origin + Vec2(w, -h / 2)
        let bottomLeft = origin + Vec2(0, -h), bottomRight = origin + Vec2(w, -h)
        switch segment {
        case 0: return (topLeft, topRight)
        case 1: return (topRight, midRight)
        case 2: return (midRight, bottomRight)
        case 3: return (bottomLeft, bottomRight)
        case 4: return (midLeft, bottomLeft)
        case 5: return (topLeft, midLeft)
        default: return (midLeft, midRight)
        }
    }

    /// The score as drawn: its decimal digits, at most ``maxDigits`` (the score is capped at 9,999,999).
    nonisolated static func scoreText(_ score: Int) -> String {
        String(String(min(max(score, 0), GameRun.maxScore)).suffix(maxDigits))
    }

    /// The wave number as drawn: its decimal digits, at most ``maxWaveDigits`` (999 and above draw 999).
    nonisolated static func waveText(_ wave: Int) -> String {
        String(min(max(wave, 1), 999))
    }

    /// The two ends of lane guide `lane` (game units): the lane centre from `driftBottom` to the top of the field, so
    /// the band with the player and the frame probe at the bottom centre stay plain field.
    nonisolated static func laneGuideEnds(_ lane: Int) -> (Vec2, Vec2) {
        let x = Lanes.centre(lane)
        return (Vec2(x, driftBottom), Vec2(x, fieldHeight))
    }

    /// Lights the segments of `text`'s digits in `nodes` from `origin` (game units) in `color`; unused nodes are
    /// cleared.
    private static func drawDigits(_ text: String, nodes: [[SceneNode]], origin: Vec2, color: Vec4,
                                   world: (Vec2) -> Vec2, width: Double) {
        let digits = text.compactMap { $0.wholeNumberValue }
        for (index, segments) in nodes.enumerated() {
            for node in segments { node.primitive = nil }
            guard index < digits.count else { continue }
            let digitOrigin = origin + Vec2(Double(index) * digitAdvance, 0)
            for segment in segmentTable[digits[index]] {
                let (a, b) = segmentEnds(segment, origin: digitOrigin)
                segments[segment].primitive = .line(world(a), world(b), width: width)
                segments[segment].color = color
            }
        }
    }

    /// A catalog colour as a vector.
    nonisolated static func vector(_ color: RGBA) -> Vec4 { Vec4(color.r, color.g, color.b, color.a) }

    /// `color` with its alpha multiplied by `alpha`.
    nonisolated static func faded(_ color: Vec4, _ alpha: Double) -> Vec4 {
        Vec4(color.x, color.y, color.z, color.w * alpha)
    }

    /// The fill and glow colours of `object` from the catalog (fallbacks when its item is unknown).
    nonisolated static func colors(_ object: FallingObject) -> (fill: Vec4, glow: Vec4) {
        if let item = ArcadeCore.catalog.item(id: object.contentId) {
            return (vector(item.color), vector(item.glowColor))
        }
        let fill = object.kind == .hazard ? fallbackHazard : fallbackOrb
        return (fill, faded(fill, 0.6))
    }

    /// Places every node for a canvas of `width` × `height` pixels (world = pixels from the centre, y up). Reads
    /// `core` only.
    func layOut(_ core: ArcadeCore, width: Double, height: Double) {
        let run = core.run
        let s = Self.scale(width: width, height: height)
        lastScale = s
        lastCanvas = Vec2(width, height)
        let pulse = pulseAmount, drift = driftAmount
        lastPulseAmount = pulse
        lastDriftAmount = drift
        let onePixel = 1.0
        func world(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }
        func px(_ units: Double) -> Double { max(units * s, onePixel) }

        field.primitive = .rect(Vec2(Self.fieldWidth * s, Self.fieldHeight * s))
        field.position = world(Vec2(Self.fieldWidth / 2, Self.fieldHeight / 2))
        field.color = Self.fieldColor

        let offset = Self.driftOffset(step: run.step, speed: drift)
        for (index, node) in driftNodes.enumerated() {
            let y = Self.driftLineY(index: index, offset: offset)
            node.primitive = .line(world(Vec2(0, y)), world(Vec2(Self.fieldWidth, y)), width: px(0.03))
            node.color = Self.driftColor
        }

        for (lane, node) in laneNodes.enumerated() {
            let (bottom, top) = Self.laneGuideEnds(lane)
            node.primitive = .line(world(bottom), world(top), width: px(Self.laneWidth))
            node.color = Self.laneColor
        }

        let glowAlpha = Self.glowAlpha(step: run.step, amount: pulse)
        var drawn = 0
        for slot in 0..<GameRun.maxObjects {
            let glow = glowNodes[slot], body = bodyNodes[slot]
            let capA = capNodes[slot].0, capB = capNodes[slot].1
            for node in [glow, body, capA, capB] { node.primitive = nil; node.position = .zero }
            guard slot < run.objects.count else { continue }
            let object = run.objects[slot]
            let (fill, glowColor) = Self.colors(object)
            glow.color = Self.faded(glowColor, glowAlpha)
            body.color = fill
            if object.isCapsule {
                let a = Vec2(object.position.x - object.halfLength, object.position.y)
                let b = Vec2(object.position.x + object.halfLength, object.position.y)
                glow.primitive = .line(world(a), world(b), width: px(2 * object.radius * Self.glowScale))
                body.primitive = .line(world(a), world(b), width: px(2 * object.radius))
                capA.primitive = .circle(px(object.radius))
                capA.position = world(a)
                capA.color = fill
                capB.primitive = .circle(px(object.radius))
                capB.position = world(b)
                capB.color = fill
            } else {
                glow.primitive = .circle(px(object.radius * Self.glowScale))
                glow.position = world(object.position)
                body.primitive = .circle(px(object.radius))
                body.position = world(object.position)
            }
            drawn += 1
        }
        lastObjectsDrawn = drawn

        let player = ArcadeCore.catalog.player
        let playerFill = player.map { Self.vector($0.color) } ?? Self.hudColor
        let playerGlowColor = player.map { Self.vector($0.glowColor) } ?? Self.faded(Self.hudColor, 0.6)
        let blinking = run.player.invulnerableSteps > 0 && (run.player.invulnerableSteps / Self.blinkSteps) % 2 == 1
        let playerAlpha = blinking ? Self.blinkAlpha : 1
        let center = run.player.center
        playerGlow.primitive = .circle(px(run.player.hitRadius * Self.glowScale))
        playerGlow.position = world(center)
        playerGlow.color = Self.faded(playerGlowColor, glowAlpha * playerAlpha)
        playerRing.primitive = .polyline(Self.ring(center: center, radius: run.player.hitRadius).map(world),
                                         width: px(Self.ringWidth))
        playerRing.color = Self.faded(playerFill, playerAlpha)
        playerChevron.primitive = .polygon(Self.chevron.map { world(center + $0) })
        playerChevron.color = Self.faded(playerFill, playerAlpha)

        let text = Self.scoreText(run.score)
        lastScoreText = text
        Self.drawDigits(text, nodes: digitNodes, origin: Self.digitOrigin, color: Self.hudColor, world: world,
                        width: px(Self.segmentWidth))
        let waveText = Self.waveText(run.wave)
        lastWaveText = waveText
        Self.drawDigits(waveText, nodes: waveDigitNodes, origin: Self.waveOrigin, color: Self.waveColor, world: world,
                        width: px(Self.segmentWidth))
        var lit = 0
        for (index, node) in lifeNodes.enumerated() {
            let alive = index < run.lives
            if alive { lit += 1 }
            node.primitive = .circle(px(Self.lifeRadius))
            node.position = world(Self.livesOrigin - Vec2(Double(index) * Self.livesSpacing, 0))
            node.color = Self.faded(playerFill, alive ? 1 : Self.lostLifeAlpha)
        }
        lastLivesLit = lit

        for (index, node) in pauseNodes.enumerated() {
            guard run.paused, !run.over else { node.primitive = nil; continue }
            node.primitive = .rect(Vec2(px(0.3), px(1.2)))
            node.position = world(Vec2(Self.fieldWidth / 2 + (index == 0 ? -0.3 : 0.3), Self.fieldHeight / 2))
            node.color = Self.pauseColor
        }
        lastStateMark = run.over ? "over" : run.paused ? "paused" : "none"
        let hazard = ArcadeCore.catalog.hazards.first.map { Self.vector($0.color) } ?? Self.fallbackHazard
        if run.over {
            shade.primitive = .rect(Vec2(Self.fieldWidth * s, Self.fieldHeight * s))
            shade.position = field.position
            shade.color = Self.overShade
            let c = Vec2(Self.fieldWidth / 2, Self.fieldHeight / 2)
            crossNodes[0].primitive = .line(world(c + Vec2(-1.2, -1.2)), world(c + Vec2(1.2, 1.2)), width: px(0.18))
            crossNodes[1].primitive = .line(world(c + Vec2(-1.2, 1.2)), world(c + Vec2(1.2, -1.2)), width: px(0.18))
            for node in crossNodes { node.color = hazard }
        } else {
            shade.primitive = nil
            for node in crossNodes { node.primitive = nil }
        }

        // Letterbox masks: everything outside the field is covered in the clear colour.
        let halfW = Self.fieldWidth / 2 * s, halfH = Self.fieldHeight / 2 * s
        let big = Vec2(max(width, 1) * 2, max(height, 1) * 2)
        let centres = [Vec2(-halfW - big.x / 2, 0), Vec2(halfW + big.x / 2, 0),
                       Vec2(0, halfH + big.y / 2), Vec2(0, -halfH - big.y / 2)]
        for (node, centre) in zip(maskNodes, centres) {
            node.primitive = .rect(big)
            node.position = centre
            node.color = Self.letterboxColor
        }
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: ArcadeCore) {
        lastCore = core
        let run = core.run
        if !mirror.ready { mirror.ready = true }
        if mirror.score != run.score { mirror.score = run.score }
        if mirror.lives != run.lives { mirror.lives = run.lives }
        if mirror.paused != run.paused { mirror.paused = run.paused }
        if mirror.over != run.over { mirror.over = run.over }
        if mirror.steering != run.steering { mirror.steering = run.steering }
        let status = Self.status(run)
        if mirror.status != status { mirror.status = status }
    }

    /// "playing", "paused" or "over".
    nonisolated static func stateWord(_ run: GameRun) -> String {
        run.over ? "over" : run.paused ? "paused" : "playing"
    }

    /// "no lives", "1 life" or "3 lives".
    nonisolated static func livesWords(_ lives: Int) -> String {
        switch lives {
        case ...0: return "no lives"
        case 1: return "1 life"
        default: return "\(lives) lives"
        }
    }

    /// "no objects falling", "1 object falling" or "5 objects falling".
    nonisolated static func objectWords(_ count: Int) -> String {
        switch count {
        case ...0: return "no objects falling"
        case 1: return "1 object falling"
        default: return "\(count) objects falling"
        }
    }

    /// The status line: "score 120, 2 lives, playing".
    nonisolated static func status(_ run: GameRun) -> String {
        "score \(run.score), \(livesWords(run.lives)), \(stateWord(run))"
    }

    /// The canvas description, for example "Neon Arcade: Neon Dodge, wave 3, score 120, 2 lives, 3 objects falling,
    /// playing."
    nonisolated static func description(_ run: GameRun) -> String {
        "Neon Arcade: Neon Dodge, wave \(run.wave), score \(run.score), \(livesWords(run.lives)), "
            + "\(objectWords(run.objects.count)), \(stateWord(run))."
    }

    /// The description of `core`'s run.
    func describe(_ core: ArcadeCore) -> String {
        sync(core)
        return Self.description(core.run)
    }

    /// The field point (game units) under the canvas point at fraction (0.5, 0.99) of the last canvas (y from the
    /// top); without a frame the field is assumed to fill the canvas height.
    func probeFieldPoint() -> Vec2 {
        guard lastScale > 0, lastCanvas.y > 0 else { return Vec2(Self.fieldWidth / 2, 0.01 * Self.fieldHeight) }
        let worldY = (0.5 - 0.99) * lastCanvas.y
        return Vec2(Self.fieldWidth / 2, worldY / lastScale + Self.fieldHeight / 2)
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

    /// The colour class of the field (and of the letterbox): `dark`.
    nonisolated static var colorClassOfField: String? {
        colorClass(red: fieldColor.x, green: fieldColor.y, blue: fieldColor.z)
    }

    /// One probe at the bottom centre of the canvas expecting the dark field (or the dark letterbox below it); none
    /// while a falling object or its glow lies within reach of that point.
    func probes(_ core: ArcadeCore) -> [FrameProbe] {
        guard let expected = Self.colorClassOfField,
              Self.colorClass(red: Self.letterboxColor.x, green: Self.letterboxColor.y,
                              blue: Self.letterboxColor.z) == expected else { return [] }
        let point = probeFieldPoint()
        if point.y >= 0 {
            for object in core.run.objects {
                let dx = max(abs(object.position.x - point.x) - object.halfLength, 0)
                let dy = object.position.y - point.y
                if (dx * dx + dy * dy).squareRoot() < object.radius * Self.glowScale + Self.probeMargin { return [] }
            }
        }
        return [FrameProbe(name: "field", x: 0.5, y: 0.99, expected: expected)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ArcadeControls(port: port, mirror: mirror))
    }

    /// Every action has a native control.
    var nativeActions: Set<String> { Set(ArcadeCore.actionIDs) }

    /// The action the canvas drag sends: `run.steer`.
    var gestureActions: Set<String> { ArcadeGestures.gestureActions }

    /// Turns a canvas pointer event into `run.steer` actions against the player of the last synced run and sends each
    /// through `port`; nothing happens before a state was seen.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let run = lastCore?.run else { return }
        followPort = port
        let actions = gestures.handle(event, playerX: run.player.x, viewSize: viewSize)
        for action in actions { _ = port.send(action.control, action.values) }
    }
}
