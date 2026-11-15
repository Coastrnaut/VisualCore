// PlaygroundPresenter — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121; clarification 5). Draws Physics
// Playground through the host only (the host's context and registry, VisualCore's `PrimitiveRenderer` with a
// `Camera2D`; no context of its own). The scene is code, rebuilt every frame from the core's world, which the presenter
// only reads:
//   - Mapping: the view is the 10 × 8 m stage plus its 1 m walls on every side (12 × 10 m, y up, centred on the stage
//     centre (5, 4) m), scaled uniformly to fit the canvas and centred; the canvas is cleared in a near-black letterbox
//     colour and four letterbox masks above everything else hide whatever lies outside the view. The simulation never
//     sees the canvas.
//   - Stage: one dark rect (the stage background) and the four walls of `WorldSimulation.walls(for:)` as grey rects.
//   - Bodies at their physics size in their material colours: a circle is a filled circle of its radius, a closed ring
//     (33 points) of its radius in the edge colour and a radius line from the centre at the body's angle, so rotation
//     shows; a box is a filled polygon of its four rotated corners with a closed outline in the edge colour. A static
//     body is drawn darker (fill × 0.55, edge × 0.7) with a hatch inside its shape (parallel lines across it, joined
//     at its edge into one path). A body whose material is not in the catalog is drawn in a neutral grey.
// There is no decorative motion, so Reduce Motion changes nothing; nothing flashes. No audio.
import Foundation
import SwiftUI
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class PlaygroundMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The number of bodies, static ones included.
    var bodyCount = 0
    /// Whether the world is paused.
    var paused = false
    /// The time-scale index, 0…3 (¼, ½, 1, 2).
    var timeScaleIndex = PhysicsWorld.normalTimeScaleIndex
    /// The status line: bodies, running or paused, time scale.
    var status = ""
}

/// A failure the presenter injects for tests (`failNextDraw`).
enum PlaygroundDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}

/// Draws Physics Playground and owns its presentation state (the scene nodes).
@MainActor
final class PlaygroundPresenter: ExperiencePresenter {
    /// The stage size in metres.
    nonisolated static let stageSize = WorldSettings.defaultStage
    /// The wall thickness in metres.
    nonisolated static let wallThickness = WorldSimulation.wallThickness
    /// The view's width and height in metres: the stage and a wall on each side.
    nonisolated static let viewWidth = stageSize.x + 2 * wallThickness, viewHeight = stageSize.y + 2 * wallThickness
    /// The stage point at the centre of the view.
    nonisolated static let viewCenter = Vec2(stageSize.x / 2, stageSize.y / 2)
    /// The clear colour around the view.
    nonisolated static let letterboxColor = Vec4(0.02, 0.02, 0.03, 1)
    /// The stage background colour (a dark navy).
    nonisolated static let stageColor = Vec4(0.06, 0.08, 0.12, 1)
    /// The wall colour.
    nonisolated static let wallColor = Vec4(0.30, 0.32, 0.36, 1)
    /// The fill and edge of a body whose material is not in the catalog.
    nonisolated static let fallbackFill = Vec4(0.6, 0.6, 0.6, 1), fallbackEdge = Vec4(0.35, 0.35, 0.35, 1)
    /// The factors a static body's fill and edge are darkened by.
    nonisolated static let staticFillFactor = 0.55, staticEdgeFactor = 0.7
    /// The width of outlines, radius lines and hatch lines in metres.
    nonisolated static let edgeWidth = 0.04
    /// The number of points of a circle's ring (closed: the last equals the first).
    nonisolated static let ringPoints = 33
    /// The spacing of the hatch of a static body in metres.
    nonisolated static let hatchSpacing = 0.25
    /// The z of the stage, the walls, the body fills, the outlines and marks, the hatch and the letterbox masks.
    nonisolated static let stageZ = 0, wallZ = 1, fillZ = 2, edgeZ = 3, hatchZ = 4, maskZ = 9
    /// The stage point (metres) near the floor at the stage's middle where the frame probe is taken.
    nonisolated static let probePoint = Vec2(5, 0.75)
    /// The clearance around the probe point (metres) a body's bounding circle must keep for the probe to be taken.
    nonisolated static let probeMargin = 0.3

    let experienceID: ExperienceID
    let mirror = PlaygroundMirror()

    /// Set by a test to make the next draw throw `PlaygroundDrawError.injected` (the seam clears itself).
    var failNextDraw = false
    /// Whether the scene is set up.
    private(set) var isLive = false
    /// The last core drawn or described.
    private(set) var lastCore: PlaygroundCore?
    /// The scale of the last frame (pixels per metre) and its canvas size in pixels.
    private(set) var lastScale = 0.0, lastCanvas = Vec2(0, 0)
    /// The number of bodies drawn in the last frame and how many of them were hatched as static.
    private(set) var lastBodiesDrawn = 0, lastStaticDrawn = 0

    private let clear = ClearColorScene(red: 0, green: 0, blue: 0)
    private var primitives: PrimitiveRenderer?
    private let root = SceneNode(id: "playground")
    /// The stage background.
    let stage = SceneNode(id: "stage", z: PlaygroundPresenter.stageZ)
    /// The four walls: floor, ceiling, left, right.
    private(set) var wallNodes: [SceneNode] = []
    /// The fill, outline, rotation mark and hatch node of each body slot.
    private(set) var fillNodes: [SceneNode] = [], edgeNodes: [SceneNode] = [], markNodes: [SceneNode] = [],
                     hatchNodes: [SceneNode] = []
    private var maskNodes: [SceneNode] = []

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
        root.add(stage)
        for index in 0..<4 {
            let node = SceneNode(id: "wall\(index)", z: Self.wallZ)
            root.add(node)
            wallNodes.append(node)
        }
        for slot in 0..<PhysicsWorld.maxBodies {
            let fill = SceneNode(id: "b\(slot)", z: Self.fillZ)
            let edge = SceneNode(id: "b\(slot).edge", z: Self.edgeZ)
            let mark = SceneNode(id: "b\(slot).mark", z: Self.edgeZ)
            let hatch = SceneNode(id: "b\(slot).hatch", z: Self.hatchZ)
            for node in [fill, edge, mark, hatch] { root.add(node) }
            fillNodes.append(fill)
            edgeNodes.append(edge)
            markNodes.append(mark)
            hatchNodes.append(hatch)
        }
        for side in 0..<4 {
            let node = SceneNode(id: "mask\(side)", z: Self.maskZ)
            root.add(node)
            maskNodes.append(node)
        }
    }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
    }

    func draw(_ core: PlaygroundCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw PlaygroundDrawError.injected
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
    }

    func teardown(_ context: RenderContext) {
        isLive = false
        primitives?.release()
        primitives = nil
    }

    // MARK: Geometry

    /// The uniform scale (pixels per metre) that fits the 12 × 10 m view into `width` × `height` pixels.
    nonisolated static func scale(width: Double, height: Double) -> Double {
        min(width / viewWidth, height / viewHeight)
    }

    /// The world point (pixels from the canvas centre, y up) of the stage point `p` (metres) at `scale`.
    nonisolated static func world(_ p: Vec2, scale: Double) -> Vec2 {
        Vec2((p.x - viewCenter.x) * scale, (p.y - viewCenter.y) * scale)
    }

    /// `local` rotated by `angle` radians (counter-clockwise) and moved to `center`.
    nonisolated static func place(_ local: Vec2, center: Vec2, angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(center.x + local.x * c - local.y * s, center.y + local.x * s + local.y * c)
    }

    /// The four corners of a box of `half` extents at `center` and `angle` (counter-clockwise from bottom-left).
    nonisolated static func corners(half: Vec2, center: Vec2, angle: Double) -> [Vec2] {
        [Vec2(-half.x, -half.y), Vec2(half.x, -half.y), Vec2(half.x, half.y), Vec2(-half.x, half.y)]
            .map { place($0, center: center, angle: angle) }
    }

    /// The closed ring of ``ringPoints`` points of `radius` around `center`.
    nonisolated static func ring(center: Vec2, radius: Double) -> [Vec2] {
        (0..<ringPoints).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints - 1)
            return center + Vec2(cos(angle) * radius, sin(angle) * radius)
        }
    }

    /// The end of the radius line of a circle of `radius` at `center` turned by `angle`.
    nonisolated static func radiusEnd(center: Vec2, radius: Double, angle: Double) -> Vec2 {
        center + Vec2(cos(angle) * radius, sin(angle) * radius)
    }

    /// The hatch inside `shape` at `center` and `angle`: a path through lines across the shape (bottom to top, then
    /// top to bottom) at x steps of about ``hatchSpacing`` (inside a circle, the chord ends at each x).
    nonisolated static func hatch(_ shape: Shape2D, center: Vec2, angle: Double) -> [Vec2] {
        let halfWidth: Double
        switch shape {
        case .circle(let radius): halfWidth = radius
        case .box(let half): halfWidth = half.x
        }
        let count = max(1, Int((2 * halfWidth / hatchSpacing).rounded(.down)))
        let step = 2 * halfWidth / Double(count + 1)
        var points: [Vec2] = []
        for k in 1...count {
            let x = -halfWidth + Double(k) * step
            let reach: Double
            switch shape {
            case .circle(let radius): reach = (max(radius * radius - x * x, 0)).squareRoot()
            case .box(let half): reach = half.y
            }
            let ends = [Vec2(x, -reach), Vec2(x, reach)]
            let ordered = k % 2 == 1 ? ends : Array(ends.reversed())
            points += ordered.map { place($0, center: center, angle: angle) }
        }
        return points
    }

    /// A material colour as a vector.
    nonisolated static func vector(_ color: RGB) -> Vec4 { Vec4(color.r, color.g, color.b, 1) }

    /// `color` with its red, green and blue multiplied by `factor`.
    nonisolated static func darkened(_ color: Vec4, _ factor: Double) -> Vec4 {
        Vec4(color.x * factor, color.y * factor, color.z * factor, color.w)
    }

    /// The fill and edge colours of `body` (darkened when static; grey when its material is unknown).
    nonisolated static func colors(_ body: PhysicsBody) -> (fill: Vec4, edge: Vec4) {
        var fill = fallbackFill, edge = fallbackEdge
        if let material = PlaygroundCore.catalog.material(id: body.materialId) {
            fill = vector(material.fill)
            edge = vector(material.edge)
        }
        guard body.isStatic else { return (fill, edge) }
        return (darkened(fill, staticFillFactor), darkened(edge, staticEdgeFactor))
    }

    /// Places every node for a canvas of `width` × `height` pixels (world = pixels from the centre, y up). Reads
    /// `core` only.
    func layOut(_ core: PlaygroundCore, width: Double, height: Double) {
        let world = core.world
        let s = Self.scale(width: width, height: height)
        lastScale = s
        lastCanvas = Vec2(width, height)
        let onePixel = 1.0
        func map(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }
        func px(_ metres: Double) -> Double { max(metres * s, onePixel) }

        stage.primitive = .rect(Vec2(Self.stageSize.x * s, Self.stageSize.y * s))
        stage.position = map(Self.viewCenter)
        stage.color = Self.stageColor
        for (node, wall) in zip(wallNodes, WorldSimulation.walls(for: world.settings)) {
            guard case .box(let half) = wall.shape else { node.primitive = nil; continue }
            node.primitive = .rect(Vec2(2 * half.x * s, 2 * half.y * s))
            node.position = map(wall.pose.position)
            node.color = Self.wallColor
        }

        var drawn = 0, hatched = 0
        for slot in 0..<PhysicsWorld.maxBodies {
            let fill = fillNodes[slot], edge = edgeNodes[slot], mark = markNodes[slot], hatch = hatchNodes[slot]
            for node in [fill, edge, mark, hatch] { node.primitive = nil; node.position = .zero }
            guard slot < world.bodies.count else { continue }
            let body = world.bodies[slot]
            guard body.isFinite else { continue }
            let (fillColor, edgeColor) = Self.colors(body)
            fill.color = fillColor
            edge.color = edgeColor
            mark.color = edgeColor
            hatch.color = edgeColor
            switch body.shape {
            case .circle(let radius):
                fill.primitive = .circle(radius * s)
                fill.position = map(body.position)
                edge.primitive = .polyline(Self.ring(center: body.position, radius: radius).map(map),
                                           width: px(Self.edgeWidth))
                mark.primitive = .line(map(body.position),
                                       map(Self.radiusEnd(center: body.position, radius: radius, angle: body.angle)),
                                       width: px(Self.edgeWidth))
            case .box(let half):
                let corners = Self.corners(half: half, center: body.position, angle: body.angle)
                fill.primitive = .polygon(corners.map(map))
                edge.primitive = .polyline((corners + [corners[0]]).map(map), width: px(Self.edgeWidth))
            }
            if body.isStatic {
                hatch.primitive = .polyline(Self.hatch(body.shape, center: body.position, angle: body.angle).map(map),
                                            width: px(Self.edgeWidth))
                hatched += 1
            }
            drawn += 1
        }
        lastBodiesDrawn = drawn
        lastStaticDrawn = hatched

        // Letterbox masks: everything outside the view is covered in the clear colour.
        let halfW = Self.viewWidth / 2 * s, halfH = Self.viewHeight / 2 * s
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
    func sync(_ core: PlaygroundCore) {
        lastCore = core
        let world = core.world
        if !mirror.ready { mirror.ready = true }
        if mirror.bodyCount != world.bodies.count { mirror.bodyCount = world.bodies.count }
        if mirror.paused != world.paused { mirror.paused = world.paused }
        if mirror.timeScaleIndex != world.timeScaleIndex { mirror.timeScaleIndex = world.timeScaleIndex }
        let status = Self.status(world)
        if mirror.status != status { mirror.status = status }
    }

    /// The time scale as shown: "¼×", "½×", "1×" or "2×" ("?" outside 0…3).
    nonisolated static func timeScaleText(_ index: Int) -> String {
        ["¼×", "½×", "1×", "2×"].indices.contains(index) ? ["¼×", "½×", "1×", "2×"][index] : "?"
    }

    /// The time scale in words: "quarter speed", "half speed", "normal speed" or "double speed".
    nonisolated static func timeScaleWords(_ index: Int) -> String {
        let words = ["quarter speed", "half speed", "normal speed", "double speed"]
        return words.indices.contains(index) ? words[index] : "unknown speed"
    }

    /// "no bodies", "1 body" or "7 bodies".
    nonisolated static func bodyWords(_ count: Int) -> String {
        switch count {
        case ...0: return "no bodies"
        case 1: return "1 body"
        default: return "\(count) bodies"
        }
    }

    /// "running" or "paused".
    nonisolated static func stateWord(_ world: PhysicsWorld) -> String { world.paused ? "paused" : "running" }

    /// The status line: "7 bodies, running, normal speed".
    nonisolated static func status(_ world: PhysicsWorld) -> String {
        "\(bodyWords(world.bodies.count)), \(stateWord(world)), \(timeScaleWords(world.timeScaleIndex))"
    }

    /// The canvas description, for example "Physics Playground: 7 bodies, running, normal speed (time scale 1×)."
    nonisolated static func description(_ world: PhysicsWorld) -> String {
        "Physics Playground: \(status(world)) (time scale \(timeScaleText(world.timeScaleIndex)))."
    }

    /// The description of `core`'s world.
    func describe(_ core: PlaygroundCore) -> String {
        sync(core)
        return Self.description(core.world)
    }

    /// The canvas fraction (x from the left, y from the top) of the stage point `p` in the last frame; without a frame
    /// the view is assumed to fill the canvas height.
    func canvasFraction(of p: Vec2) -> Vec2 {
        guard lastScale > 0, lastCanvas.x > 0, lastCanvas.y > 0 else {
            return Vec2(0.5, 0.5 - (p.y - Self.viewCenter.y) / Self.viewHeight)
        }
        let w = Self.world(p, scale: lastScale)
        return Vec2(0.5 + w.x / lastCanvas.x, 0.5 - w.y / lastCanvas.y)
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

    /// The colour class of the stage background: `dark`.
    nonisolated static var colorClassOfStage: String? {
        colorClass(red: stageColor.x, green: stageColor.y, blue: stageColor.z)
    }

    /// One probe on the stage background near the floor at the middle, expecting `dark`; none while a body's bounding
    /// circle comes within ``probeMargin`` of that point.
    func probes(_ core: PlaygroundCore) -> [FrameProbe] {
        guard let expected = Self.colorClassOfStage else { return [] }
        for body in core.world.bodies {
            if (body.position - Self.probePoint).length < body.boundingRadius + Self.probeMargin { return [] }
        }
        let fraction = canvasFraction(of: Self.probePoint)
        return [FrameProbe(name: "stage", x: fraction.x, y: fraction.y, expected: expected)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(PlaygroundControls(port: port, mirror: mirror))
    }

    /// Every action has a native control; there is no canvas gesture.
    var nativeActions: Set<String> { Set(PlaygroundCore.actionIDs) }
}
