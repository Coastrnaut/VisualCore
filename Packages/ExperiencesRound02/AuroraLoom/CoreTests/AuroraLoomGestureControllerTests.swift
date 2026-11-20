// AuroraLoomGestureControllerTests — feature 304 (R02-G01-04) T-R02G0104-003 (FR-R02G0104-002, 003, 006;
// SC-R02G0104-001, 002; clarifications Q1–Q3, Q5; research R2, R3). Scripted touches at fixed view sizes (390 × 844,
// 96 × 64, 1,024 × 768): 500 seeded drags along anchor rails and around dials end in exactly the move the end point
// names, computed independently here from the target step (or nothing when it equals the start); 1,000 seeded
// arbitration scripts (second finger mid-drag, cancelled touches, empty space, not playing, unknown ids and non-finite
// locations, random event soup) never send a move they should not; two handles under one touch pick the nearest by
// R02-F22's rule; the orbit follows the two-finger midpoint (90° per width, 60° per height), clamps at its limits and
// resets by resetOrbit and by a double tap on empty space; the selection follows the last picked handle and
// select(ribbon:); the same script gives the same results.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@Suite struct AuroraLoomGestureControllerTests {
    typealias Controller = AuroraLoomGestureController

    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(96, 64), Vec2(1_024, 768)]
    /// The seed of the scripted drags.
    static let dragSeed: UInt64 = 2_304
    /// The seed of the arbitration scripts.
    static let arbitrationSeed: UInt64 = 2_304_001
    /// The time between scripted events in seconds.
    static let frame = 1.0 / 60

    // MARK: Helpers

    /// The drawn camera's view-projection at `orbit` for `view`.
    static func viewProjection(view: Vec2, orbit: AuroraLoomOrbit = .authored) -> Mat4 {
        let camera: (view: Mat4, projection: Mat4) = AuroraLoomSceneGeometry.camera(aspect: view.x / view.y,
                                                                                     orbit: orbit)
        return camera.projection * camera.view
    }

    /// The authored view-projection of each of `views`, computed once (the camera fit is a bisection).
    static let authoredViewProjections: [Mat4] = {
        var result: [Mat4] = []
        for view in views { result.append(viewProjection(view: view)) }
        return result
    }()

    /// The screen point of `world` through the drawn camera at `orbit` for `view`, or nil behind the camera.
    static func screen(_ world: Vec3, view: Vec2, orbit: AuroraLoomOrbit = .authored) -> Vec2? {
        var matrix: Mat4? = nil
        if orbit == .authored, let index = views.firstIndex(of: view) { matrix = authoredViewProjections[index] }
        let vp: Mat4 = matrix ?? viewProjection(view: view, orbit: orbit)
        return ScreenProjection.project(world, viewProjection: vp, viewport: view)?.point
    }

    /// Whether `point` lies inside `view` (edges included).
    static func inside(_ point: Vec2, view: Vec2) -> Bool {
        point.x >= 0 && point.x <= view.x && point.y >= 0 && point.y <= view.y
    }

    /// The handle the shared picker chooses at `point` (independent of the controller), or nil.
    static func pickedByPicker(_ point: Vec2, view: Vec2, steps: AuroraLoomSteps,
                               orbit: AuroraLoomOrbit = .authored) throws -> AuroraLoomHandleID? {
        var matrix: Mat4? = nil
        if orbit == .authored, let index = views.firstIndex(of: view) { matrix = authoredViewProjections[index] }
        let vp: Mat4 = matrix ?? viewProjection(view: view, orbit: orbit)
        let handles: [SpatialHandle] = try AuroraLoomHandles.spatialHandles(steps: steps)
        guard let index = try HandlePicker.pick(handles, at: point, viewProjection: vp,
                                                viewport: view) else { return nil }
        return AuroraLoomHandleID(raw: handles[index].id)
    }

    /// Random steps 0 … 15 for each of three ribbons.
    static func randomSteps(_ random: inout SeededRandom) -> AuroraLoomSteps {
        var wave: [Int] = []
        var phase: [Int] = []
        for _ in 0..<3 {
            wave.append(random.int(0...15))
            phase.append(random.int(0...15))
        }
        return AuroraLoomSteps(wave: wave, phase: phase)
    }

    /// A one-finger script: down at the first point, moved through the rest, then ended (or cancelled).
    static func stroke(_ points: [Vec2], id: Int, time: Double, cancelled: Bool = false) -> [PointerEvent] {
        var events: [PointerEvent] = []
        var t: Double = time
        events.append(PointerEvent(id: id, phase: .began, location: points[0], timestamp: t))
        var index: Int = 1
        while index < points.count {
            t += frame
            events.append(PointerEvent(id: id, phase: .moved, location: points[index], timestamp: t))
            index += 1
        }
        t += frame
        events.append(PointerEvent(id: id, phase: cancelled ? .cancelled : .ended, location: points[points.count - 1],
                                   timestamp: t))
        return events
    }

    /// Feeds `events` and returns every move returned.
    static func run(_ controller: inout Controller, _ events: [PointerEvent], view: Vec2, steps: AuroraLoomSteps,
                    playing: Bool = true) -> [AuroraLoomMove] {
        var moves: [AuroraLoomMove] = []
        for event in events {
            if let move = controller.handle(event, viewSize: view, steps: steps, playing: playing) {
                moves.append(move)
            }
        }
        return moves
    }

    /// The world path of a drag of `handle` from its step in `steps` to `target`: one point per crossed step (anchor:
    /// rail heights, dial: knob angles), ending exactly at the target. `overshoot` adds a last anchor point beyond the
    /// rail end in the target's direction.
    static func path(_ handle: AuroraLoomHandleID, steps: AuroraLoomSteps, delta: Int, overshoot: Bool) -> [Vec3] {
        var points: [Vec3] = []
        let r: Int = handle.ribbon
        switch handle.control {
        case .wave:
            let start: Int = steps.wave[r]
            let step: Int = delta >= 0 ? 1 : -1
            var k: Int = 0
            while true {
                points.append(AuroraLoomHandles.anchorPosition(ribbon: r, wave: start + k))
                if k == delta { break }
                k += step
            }
            if overshoot {
                let y: Double = delta >= 0 ? 1.3 : -1.3
                points.append(Vec3(AuroraLoomHandles.railX, y, AuroraLoomSceneGeometry.lane(ribbon: r)))
            }
        case .phase:
            let start: Int = steps.phase[r]
            let step: Int = delta >= 0 ? 1 : -1
            var k: Int = 0
            while true {
                points.append(AuroraLoomHandles.dialKnob(ribbon: r, phase: start + k))
                if k == delta { break }
                k += step
            }
        }
        return points
    }

    /// The expected end step of a drag, computed from the target alone: the wave target clamped to 0 … 15 (0 or 15 on
    /// an overshoot), the phase target modulo 16.
    static func expectedStep(_ handle: AuroraLoomHandleID, start: Int, delta: Int, overshoot: Bool) -> Int {
        switch handle.control {
        case .wave:
            if overshoot { return delta >= 0 ? 15 : 0 }
            return min(max(start + delta, 0), 15)
        case .phase:
            return ((start + delta) % 16 + 16) % 16
        }
    }

    /// One seeded scripted drag: its view, steps, handle, expected move and events; nil when a point leaves the view.
    struct DragCase {
        let view: Vec2
        let steps: AuroraLoomSteps
        let handle: AuroraLoomHandleID
        let expected: AuroraLoomMove?
        let events: [PointerEvent]
    }

    /// Draws one scripted drag from `random`.
    static func dragCase(_ random: inout SeededRandom, index: Int) -> DragCase? {
        let view: Vec2 = views[random.int(0...2)]
        let steps: AuroraLoomSteps = randomSteps(&random)
        let ribbon: Int = random.int(0...2)
        let control: AuroraLoomControl = random.int(0...1) == 0 ? .wave : .phase
        guard let handle = AuroraLoomHandleID(ribbon: ribbon, control: control) else { return nil }
        let start: Int = control == .wave ? steps.wave[ribbon] : steps.phase[ribbon]
        var delta: Int
        var overshoot: Bool = false
        if control == .wave {
            let target: Int = random.int(0...15)
            delta = target - start
            overshoot = random.int(0...9) == 0 && delta != 0
        } else {
            delta = random.int(-8...8)
            let extra: Int = random.int(0...5)
            if extra == 0 { delta += 16 } else if extra == 1 { delta -= 16 }
        }
        let world: [Vec3] = path(handle, steps: steps, delta: delta, overshoot: overshoot)
        var screenPath: [Vec2] = []
        for p in world {
            guard let s = screen(p, view: view), inside(s, view: view) else { return nil }
            screenPath.append(s)
        }
        let step: Int = expectedStep(handle, start: start, delta: delta, overshoot: overshoot)
        let expected: AuroraLoomMove? = step == start ? nil : AuroraLoomMove(ribbon: ribbon, control: control,
                                                                             step: step)
        let events: [PointerEvent] = stroke(screenPath, id: index % 7 + 1, time: Double(index))
        return DragCase(view: view, steps: steps, handle: handle, expected: expected, events: events)
    }

    // MARK: Scripted drags

    @Test func fiveHundredSeededDragsEndInTheIndependentlyComputedStep() throws {
        var random: SeededRandom = SeededRandom(seed: Self.dragSeed)
        var checked: Int = 0
        var moves: Int = 0
        var index: Int = 0
        while index < 500 {
            guard let drag = Self.dragCase(&random, index: index) else {
                Issue.record("drag \(index) left the view")
                index += 1
                continue
            }
            var controller: Controller = Controller()
            let result: [AuroraLoomMove] = Self.run(&controller, drag.events, view: drag.view, steps: drag.steps)
            if let expected = drag.expected {
                #expect(result == [expected], "drag \(index) \(drag.handle) at \(drag.view)")
                moves += 1
            } else {
                #expect(result.isEmpty, "drag \(index) returned to its start")
            }
            #expect(controller.phase == .idle)
            #expect(controller.preview == nil)
            #expect(controller.selectedRibbon == drag.handle.ribbon)
            checked += 1
            index += 1
        }
        #expect(checked == 500)
        #expect(moves > 400)
    }

    @Test func dragPreviewFollowsTheFingerAndOnlyTheReleaseSends() throws {
        let view: Vec2 = Vec2(390, 844)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [3, 7, 12], phase: [0, 5, 15])
        guard let handle = AuroraLoomHandleID(ribbon: 1, control: .wave) else { return }
        let world: [Vec3] = Self.path(handle, steps: steps, delta: 3, overshoot: false)
        var points: [Vec2] = []
        for p in world { points.append(try #require(Self.screen(p, view: view))) }
        var controller: Controller = Controller()
        let began: PointerEvent = PointerEvent(id: 4, phase: .began, location: points[0], timestamp: 0)
        #expect(controller.handle(began, viewSize: view, steps: steps, playing: true) == nil)
        #expect(controller.phase == .dragging(handle, start: 7, candidate: 7))
        #expect(controller.preview == AuroraLoomMove(ribbon: 1, control: .wave, step: 7))
        var k: Int = 1
        while k < points.count {
            let moved: PointerEvent = PointerEvent(id: 4, phase: .moved, location: points[k], timestamp: Double(k))
            #expect(controller.handle(moved, viewSize: view, steps: steps, playing: true) == nil)
            #expect(controller.preview == AuroraLoomMove(ribbon: 1, control: .wave, step: 7 + k))
            k += 1
        }
        let ended: PointerEvent = PointerEvent(id: 4, phase: .ended, location: points[3], timestamp: 9)
        #expect(controller.handle(ended, viewSize: view, steps: steps, playing: true)
                == AuroraLoomMove(ribbon: 1, control: .wave, step: 10))
        #expect(controller.phase == .idle)
    }

    @Test func quarterTurnOfADialIsFourPhaseSteps() throws {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [3, 7, 12], phase: [14, 5, 15])
        for view in Self.views {
            guard let handle = AuroraLoomHandleID(ribbon: 0, control: .phase) else { return }
            let world: [Vec3] = Self.path(handle, steps: steps, delta: 4, overshoot: false)
            var points: [Vec2] = []
            for p in world { points.append(try #require(Self.screen(p, view: view))) }
            var controller: Controller = Controller()
            let moves: [AuroraLoomMove] = Self.run(&controller, Self.stroke(points, id: 1, time: 0), view: view,
                                                   steps: steps)
            #expect(moves == [AuroraLoomMove(ribbon: 0, control: .phase, step: 2)], "view \(view)")
        }
    }

    // MARK: Arbitration

    /// A point of `view` where the shared picker finds no handle, drawn from `random`.
    static func emptyPoint(_ random: inout SeededRandom, view: Vec2, steps: AuroraLoomSteps) throws -> Vec2? {
        var attempt: Int = 0
        while attempt < 50 {
            let p: Vec2 = Vec2(random.range(0...view.x), random.range(0...view.y))
            if try pickedByPicker(p, view: view, steps: steps) == nil { return p }
            attempt += 1
        }
        return nil
    }

    @Test func oneThousandSeededArbitrationScriptsNeverSendAnUnwantedMove() throws {
        var random: SeededRandom = SeededRandom(seed: Self.arbitrationSeed)
        var counts: [Int] = [0, 0, 0, 0, 0, 0]
        var script: Int = 0
        while script < 1_000 {
            let kind: Int = script % 6
            guard let drag = Self.dragCase(&random, index: script) else {
                Issue.record("script \(script) left the view")
                script += 1
                continue
            }
            var controller: Controller = Controller()
            let initial: Int = (drag.handle.ribbon + 1) % 3
            controller.select(ribbon: initial)
            let view: Vec2 = drag.view
            var moves: [AuroraLoomMove] = []
            switch kind {
            case 0:
                // A second finger mid-drag cancels the drag and orbits; nothing is sent.
                let half: Int = max(1, drag.events.count / 2)
                for event in drag.events.prefix(half) {
                    if let m = controller.handle(event, viewSize: view, steps: drag.steps, playing: true) {
                        moves.append(m)
                    }
                }
                let second: Vec2 = Vec2(random.range(0...view.x), random.range(0...view.y))
                let t: Double = Double(script) + 0.5
                let down: PointerEvent = PointerEvent(id: 99, phase: .began, location: second, timestamp: t)
                if let m = controller.handle(down, viewSize: view, steps: drag.steps, playing: true) { moves.append(m) }
                #expect(controller.phase == .orbiting)
                #expect(controller.preview == nil)
                for event in drag.events.suffix(from: half) {
                    if let m = controller.handle(event, viewSize: view, steps: drag.steps, playing: true) {
                        moves.append(m)
                    }
                }
                #expect(controller.phase == .cancelled)
                let up: PointerEvent = PointerEvent(id: 99, phase: .ended, location: second, timestamp: t + 1)
                if let m = controller.handle(up, viewSize: view, steps: drag.steps, playing: true) { moves.append(m) }
                #expect(controller.phase == .idle)
            case 1:
                // A cancelled touch ends the drag without a move.
                var events: [PointerEvent] = drag.events
                let last: PointerEvent = events[events.count - 1]
                events[events.count - 1] = PointerEvent(id: last.id, phase: .cancelled, location: last.location,
                                                        timestamp: last.timestamp)
                moves = Self.run(&controller, events, view: view, steps: drag.steps)
                #expect(controller.phase == .idle)
            case 2:
                // A touch on empty space selects nothing and sends nothing.
                guard let p = try Self.emptyPoint(&random, view: view, steps: drag.steps) else {
                    Issue.record("no empty point at \(view)")
                    script += 1
                    continue
                }
                let q: Vec2 = Vec2(min(max(p.x + random.range(-30...30), 0), view.x),
                                   min(max(p.y + random.range(-30...30), 0), view.y))
                moves = Self.run(&controller, Self.stroke([p, q], id: 3, time: Double(script)), view: view,
                                 steps: drag.steps)
                #expect(controller.selectedRibbon == initial)
                #expect(controller.phase == .idle)
            case 3:
                // Not playing: handles never respond.
                var dragged: Bool = false
                for event in drag.events {
                    if let m = controller.handle(event, viewSize: view, steps: drag.steps, playing: false) {
                        moves.append(m)
                    }
                    if case .dragging = controller.phase { dragged = true }
                }
                #expect(!dragged)
                #expect(controller.selectedRibbon == initial)
            case 4:
                // Unknown ids, repeated downs, non-finite locations and unusable views: no crash, no move.
                let bad: [Vec2] = [Vec2(.nan, 10), Vec2(10, .infinity), Vec2(-.infinity, .nan)]
                let t: Double = Double(script)
                var events: [PointerEvent] = []
                events.append(PointerEvent(id: 50, phase: .moved, location: Vec2(10, 10), timestamp: t))
                events.append(PointerEvent(id: 51, phase: .ended, location: Vec2(10, 10), timestamp: t))
                events.append(PointerEvent(id: 52, phase: .cancelled, location: Vec2(10, 10), timestamp: t))
                for b in bad { events.append(PointerEvent(id: 53, phase: .began, location: b, timestamp: t)) }
                events.append(contentsOf: drag.events.dropLast())
                events.append(PointerEvent(id: drag.events[0].id, phase: .began, location: Vec2(1, 1), timestamp: t))
                for b in bad {
                    events.append(PointerEvent(id: drag.events[0].id, phase: .moved, location: b, timestamp: t))
                }
                events.append(PointerEvent(id: drag.events[0].id, phase: .cancelled, location: Vec2(.nan, .nan),
                                           timestamp: .nan))
                moves = Self.run(&controller, events, view: view, steps: drag.steps)
                let sizes: [Vec2] = [Vec2(0, 0), Vec2(.nan, 10), Vec2(-5, 5), Vec2(.infinity, 3)]
                for size in sizes {
                    let stroke: [PointerEvent] = Self.stroke([Vec2(5, 5), Vec2(6, 6)], id: 60, time: t)
                    moves.append(contentsOf: Self.run(&controller, stroke, view: size, steps: drag.steps))
                }
                let broken: AuroraLoomSteps = AuroraLoomSteps(wave: [], phase: [])
                moves.append(contentsOf: Self.run(&controller, drag.events, view: view, steps: broken))
                #expect(controller.phase == .idle)
            default:
                // Random event soup: any move comes from an `.ended` event and is in range.
                var t: Double = Double(script)
                var n: Int = 0
                while n < 40 {
                    let id: Int = random.int(0...3)
                    let phase: PointerPhase = [PointerPhase.began, .moved, .moved, .ended, .cancelled][random.int(0...4)]
                    let p: Vec2 = random.int(0...19) == 0
                        ? Vec2(.nan, 1) : Vec2(random.range(-10...(view.x + 10)), random.range(-10...(view.y + 10)))
                    t += Self.frame
                    let event: PointerEvent = PointerEvent(id: id, phase: phase, location: p, timestamp: t)
                    if let m = controller.handle(event, viewSize: view, steps: drag.steps, playing: true) {
                        #expect(phase == .ended)
                        #expect((0...2).contains(m.ribbon))
                        #expect((0...15).contains(m.step))
                    }
                    n += 1
                }
                moves = []
            }
            #expect(moves.isEmpty, "script \(script) kind \(kind)")
            counts[kind] += 1
            script += 1
        }
        var total: Int = 0
        for c in counts { total += c }
        #expect(total == 1_000)
    }

    @Test func aDragAfterAnOrbitUsesTheOrbitedCamera() throws {
        let view: Vec2 = Vec2(1_024, 768)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [2, 9, 4], phase: [0, 0, 0])
        var controller: Controller = Controller()
        let fingers: [PointerEvent] = [
            PointerEvent(id: 1, phase: .began, location: Vec2(400, 300), timestamp: 0),
            PointerEvent(id: 2, phase: .began, location: Vec2(500, 300), timestamp: 0),
            PointerEvent(id: 1, phase: .moved, location: Vec2(500, 400), timestamp: 0.1),
            PointerEvent(id: 2, phase: .moved, location: Vec2(600, 400), timestamp: 0.1),
            PointerEvent(id: 1, phase: .ended, location: Vec2(500, 400), timestamp: 0.2),
            PointerEvent(id: 2, phase: .ended, location: Vec2(600, 400), timestamp: 0.2),
        ]
        #expect(Self.run(&controller, fingers, view: view, steps: steps).isEmpty)
        let orbit: AuroraLoomOrbit = controller.orbit
        #expect(orbit != .authored)
        guard let handle = AuroraLoomHandleID(ribbon: 2, control: .wave) else { return }
        var points: [Vec2] = []
        for p in Self.path(handle, steps: steps, delta: 6, overshoot: false) {
            points.append(try #require(Self.screen(p, view: view, orbit: orbit)))
        }
        let moves: [AuroraLoomMove] = Self.run(&controller, Self.stroke(points, id: 5, time: 1), view: view,
                                               steps: steps)
        #expect(moves == [AuroraLoomMove(ribbon: 2, control: .wave, step: 10)])
    }

    // MARK: Picking

    @Test func twoHandlesUnderOneTouchPickTheNearestByThePickerRule() throws {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [5, 6, 7], phase: [3, 4, 5])
        var compared: Int = 0
        var nearestChecked: Int = 0
        for view in Self.views {
            for a in 0..<6 {
                for b in 0..<6 where b != a {
                    guard let ha = AuroraLoomHandleID(raw: a), let hb = AuroraLoomHandleID(raw: b),
                          let pa = Self.screen(AuroraLoomHandles.position(of: ha, steps: steps), view: view),
                          let pb = Self.screen(AuroraLoomHandles.position(of: hb, steps: steps), view: view)
                    else { continue }
                    let fractions: [Double] = [0.25, 0.5, 0.75]
                    for f in fractions {
                        let touch: Vec2 = pa + (pb - pa) * f
                        let expected: AuroraLoomHandleID? = try Self.pickedByPicker(touch, view: view, steps: steps)
                        var controller: Controller = Controller()
                        let down: PointerEvent = PointerEvent(id: 1, phase: .began, location: touch, timestamp: 0)
                        _ = controller.handle(down, viewSize: view, steps: steps, playing: true)
                        if let expected {
                            guard case .dragging(let picked, _, _) = controller.phase else {
                                Issue.record("no drag at \(touch) in \(view)")
                                continue
                            }
                            #expect(picked == expected)
                            // Nearest wins, computed here: when one handle is strictly nearest on screen within the
                            // touch radius, it is the one picked.
                            if let nearest = Self.uniquelyNearest(touch, view: view, steps: steps) {
                                #expect(picked == nearest, "\(ha) vs \(hb) at \(view)")
                                nearestChecked += 1
                            }
                            compared += 1
                        } else {
                            #expect(controller.phase == .idle)
                        }
                    }
                }
            }
        }
        #expect(compared > 0)
        #expect(nearestChecked > 0)
    }

    /// The handle strictly nearest to `touch` on screen (by more than 1e-6 points) within the minimum touch radius,
    /// computed from the handle positions alone; nil when none is in reach or the nearest two are (almost) tied.
    static func uniquelyNearest(_ touch: Vec2, view: Vec2, steps: AuroraLoomSteps) -> AuroraLoomHandleID? {
        var best: (id: AuroraLoomHandleID, distance: Double)? = nil
        var second: Double = Double.infinity
        for id in AuroraLoomHandleID.all {
            guard let p = screen(AuroraLoomHandles.position(of: id, steps: steps), view: view) else { continue }
            let d: Double = (p - touch).length
            if let current = best, d >= current.distance {
                second = min(second, d)
                continue
            }
            if let current = best { second = min(second, current.distance) }
            best = (id, d)
        }
        guard let best, best.distance <= HandlePicker.minimumTouchRadius, second - best.distance > 1e-6 else {
            return nil
        }
        return best.id
    }

    @Test func equidistantHandlesTieToTheLowerID() throws {
        // Two anchors of neighbouring lanes at one height project close together on the tiny view; at the exact
        // midpoint the picker's tie rule (depth, then the lower index, which is the lower id) decides, and the
        // controller follows it.
        let view: Vec2 = Vec2(96, 64)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [8, 8, 8], phase: [0, 0, 0])
        guard let h0 = AuroraLoomHandleID(ribbon: 0, control: .wave),
              let h1 = AuroraLoomHandleID(ribbon: 1, control: .wave) else { return }
        let p0: Vec2 = try #require(Self.screen(AuroraLoomHandles.position(of: h0, steps: steps), view: view))
        let p1: Vec2 = try #require(Self.screen(AuroraLoomHandles.position(of: h1, steps: steps), view: view))
        let touch: Vec2 = (p0 + p1) * 0.5
        let pickedByPicker: AuroraLoomHandleID? = try Self.pickedByPicker(touch, view: view, steps: steps)
        let expected: AuroraLoomHandleID = try #require(pickedByPicker)
        var controller: Controller = Controller()
        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: touch, timestamp: 0), viewSize: view,
                              steps: steps, playing: true)
        guard case .dragging(let picked, _, _) = controller.phase else {
            Issue.record("no drag")
            return
        }
        #expect(picked == expected)
        #expect(picked.raw <= 2)
    }

    // MARK: Orbit

    /// Two fingers down at `a` and `b`, both moved by `delta`, then lifted one by one.
    static func orbitScript(a: Vec2, b: Vec2, delta: Vec2, time: Double) -> [PointerEvent] {
        [PointerEvent(id: 1, phase: .began, location: a, timestamp: time),
         PointerEvent(id: 2, phase: .began, location: b, timestamp: time),
         PointerEvent(id: 1, phase: .moved, location: a + delta, timestamp: time + 0.05),
         PointerEvent(id: 2, phase: .moved, location: b + delta, timestamp: time + 0.05),
         PointerEvent(id: 1, phase: .ended, location: a + delta, timestamp: time + 0.1),
         PointerEvent(id: 2, phase: .ended, location: b + delta, timestamp: time + 0.1)]
    }

    @Test func orbitFollowsTheMidpointAndClampsAtItsLimits() throws {
        let view: Vec2 = Vec2(390, 844)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [1, 2, 3], phase: [4, 5, 6])
        let degree: Double = Double.pi / 180
        var controller: Controller = Controller()
        // A tenth of the width right: +9° azimuth; a tenth of the height down: +6° elevation.
        var events: [PointerEvent] = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(39, 84.4),
                                                      time: 0)
        var index: Int = 0
        for event in events {
            #expect(controller.handle(event, viewSize: view, steps: steps, playing: true) == nil)
            if index == 1 { #expect(controller.phase == .orbiting) }
            if index == 4 { #expect(controller.phase == .cancelled) }
            index += 1
        }
        #expect(controller.phase == .idle)
        #expect(abs(controller.orbit.azimuthOffset - 9 * degree) < 1e-9)
        #expect(abs(controller.orbit.elevation - (AuroraLoomOrbit.authored.elevation + 6 * degree)) < 1e-9)
        // Far right and down: both at their upper limits.
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(5_000, 5_000), time: 1)
        _ = Self.run(&controller, events, view: view, steps: steps)
        #expect(controller.orbit.azimuthOffset == AuroraLoomOrbit.azimuthRange.upperBound)
        #expect(controller.orbit.elevation == AuroraLoomOrbit.elevationRange.upperBound)
        // Far left and up: both at their lower limits.
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(-9_000, -9_000), time: 2)
        _ = Self.run(&controller, events, view: view, steps: steps)
        #expect(controller.orbit.azimuthOffset == AuroraLoomOrbit.azimuthRange.lowerBound)
        #expect(controller.orbit.elevation == AuroraLoomOrbit.elevationRange.lowerBound)
        controller.resetOrbit()
        #expect(controller.orbit == .authored)
        // Orbiting works while not playing.
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(39, 0), time: 3)
        _ = Self.run(&controller, events, view: view, steps: steps, playing: false)
        #expect(abs(controller.orbit.azimuthOffset - 9 * degree) < 1e-9)
        // A cancelled finger ends the orbit; the rest lift to idle.
        controller.cancel()
        #expect(controller.phase == .idle)
        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: Vec2(10, 10), timestamp: 4),
                              viewSize: view, steps: steps, playing: true)
        _ = controller.handle(PointerEvent(id: 2, phase: .began, location: Vec2(30, 10), timestamp: 4),
                              viewSize: view, steps: steps, playing: true)
        _ = controller.handle(PointerEvent(id: 2, phase: .cancelled, location: Vec2(30, 10), timestamp: 4.1),
                              viewSize: view, steps: steps, playing: true)
        #expect(controller.phase == .cancelled)
        _ = controller.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(10, 10), timestamp: 4.2),
                              viewSize: view, steps: steps, playing: true)
        #expect(controller.phase == .idle)
    }

    @Test func doubleTapOnEmptySpaceResetsTheOrbit() throws {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [1, 2, 3], phase: [4, 5, 6])
        for view in Self.views {
            let corner: Vec2 = Vec2(2, 2)
            #expect(try Self.pickedByPicker(corner, view: view, steps: steps) == nil)
            let turn: [PointerEvent] = Self.orbitScript(a: Vec2(view.x * 0.3, view.y * 0.5),
                                                        b: Vec2(view.x * 0.6, view.y * 0.5),
                                                        delta: Vec2(view.x * 0.2, view.y * 0.2), time: 0)
            // Taps 0.2 s apart, 5 pt apart: reset.
            var controller: Controller = Controller()
            _ = Self.run(&controller, turn, view: view, steps: steps)
            #expect(controller.orbit != .authored)
            var taps: [PointerEvent] = Self.stroke([corner], id: 7, time: 10)
            taps.append(contentsOf: Self.stroke([corner + Vec2(3, 4)], id: 8, time: 10.2))
            #expect(Self.run(&controller, taps, view: view, steps: steps).isEmpty)
            #expect(controller.orbit == .authored, "view \(view)")
            // Too slow: no reset.
            _ = Self.run(&controller, turn, view: view, steps: steps)
            taps = Self.stroke([corner], id: 7, time: 20)
            taps.append(contentsOf: Self.stroke([corner], id: 8, time: 20.4))
            _ = Self.run(&controller, taps, view: view, steps: steps)
            #expect(controller.orbit != .authored)
            // Too far apart: no reset.
            controller.resetOrbit()
            _ = Self.run(&controller, turn, view: view, steps: steps)
            let far: Vec2 = Vec2(min(corner.x + 30, view.x), corner.y)
            if try Self.pickedByPicker(far, view: view, steps: steps) == nil {
                taps = Self.stroke([corner], id: 7, time: 30)
                taps.append(contentsOf: Self.stroke([far], id: 8, time: 30.1))
                _ = Self.run(&controller, taps, view: view, steps: steps)
                #expect(controller.orbit != .authored)
            }
            // A tap that travels more than 20 pt is not a tap.
            controller.resetOrbit()
            _ = Self.run(&controller, turn, view: view, steps: steps)
            let slide: Vec2 = Vec2(corner.x, min(corner.y + 25, view.y))
            taps = Self.stroke([corner, slide, corner], id: 7, time: 40)
            taps.append(contentsOf: Self.stroke([corner], id: 8, time: 40.1))
            _ = Self.run(&controller, taps, view: view, steps: steps)
            #expect(controller.orbit != .authored)
        }
    }

    // MARK: Selection

    @Test func selectionFollowsTheLastPickedHandleAndSelect() throws {
        let view: Vec2 = Vec2(390, 844)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [1, 2, 3], phase: [4, 5, 6])
        var controller: Controller = Controller()
        #expect(controller.selectedRibbon == 0)
        #expect(controller.phase == .idle)
        #expect(controller.orbit == .authored)
        #expect(controller.preview == nil)
        let ids: [Int] = [5, 2, 1, 4, 0, 3]
        for raw in ids {
            guard let handle = AuroraLoomHandleID(raw: raw) else { continue }
            let p: Vec2 = try #require(Self.screen(AuroraLoomHandles.position(of: handle, steps: steps), view: view))
            let moves: [AuroraLoomMove] = Self.run(&controller, Self.stroke([p], id: 1, time: Double(raw)),
                                                   view: view, steps: steps)
            #expect(moves.isEmpty)
            #expect(controller.selectedRibbon == handle.ribbon)
        }
        controller.select(ribbon: 1)
        #expect(controller.selectedRibbon == 1)
        controller.select(ribbon: 7)
        controller.select(ribbon: -1)
        #expect(controller.selectedRibbon == 1)
        controller.select(ribbon: 2)
        #expect(controller.selectedRibbon == 2)
    }

    @Test func cancelDropsADragWithoutAMove() throws {
        let view: Vec2 = Vec2(96, 64)
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [1, 2, 3], phase: [4, 5, 6])
        guard let handle = AuroraLoomHandleID(ribbon: 2, control: .wave) else { return }
        var points: [Vec2] = []
        for p in Self.path(handle, steps: steps, delta: 5, overshoot: false) {
            points.append(try #require(Self.screen(p, view: view)))
        }
        let events: [PointerEvent] = Self.stroke(points, id: 1, time: 0)
        var controller: Controller = Controller()
        for event in events.dropLast() { _ = controller.handle(event, viewSize: view, steps: steps, playing: true) }
        #expect(controller.preview == AuroraLoomMove(ribbon: 2, control: .wave, step: 8))
        controller.cancel()
        #expect(controller.phase == .cancelled)
        #expect(controller.preview == nil)
        #expect(controller.handle(events[events.count - 1], viewSize: view, steps: steps, playing: true) == nil)
        #expect(controller.phase == .idle)
        // A level that stops playing before the release sends nothing either.
        var other: Controller = Controller()
        for event in events.dropLast() { _ = other.handle(event, viewSize: view, steps: steps, playing: true) }
        #expect(other.handle(events[events.count - 1], viewSize: view, steps: steps, playing: false) == nil)
    }

    // MARK: Determinism

    @Test func theSameScriptGivesTheSameResults() throws {
        var results: [[String]] = []
        for _ in 0..<2 {
            var random: SeededRandom = SeededRandom(seed: Self.dragSeed)
            var lines: [String] = []
            var index: Int = 0
            while index < 120 {
                if let drag = Self.dragCase(&random, index: index) {
                    var controller: Controller = Controller()
                    var events: [PointerEvent] = drag.events
                    events.insert(contentsOf: Self.orbitScript(a: Vec2(10, 10), b: Vec2(40, 20),
                                                               delta: Vec2(Double(index % 13), 3), time: -1), at: 0)
                    let moves: [AuroraLoomMove] = Self.run(&controller, events, view: drag.view, steps: drag.steps)
                    lines.append("\(moves) \(controller.phase) \(controller.selectedRibbon) \(controller.orbit)")
                }
                index += 1
            }
            results.append(lines)
        }
        #expect(results[0] == results[1])
        #expect(results[0].count == 120)
    }
}
