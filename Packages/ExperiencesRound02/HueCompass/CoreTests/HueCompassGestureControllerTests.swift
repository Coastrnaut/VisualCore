// HueCompassGestureControllerTests — feature 334 (R02-G04-04) T-R02G0404-003 (FR-R02G0404-001 … 004;
// SC-R02G0404-001, 002; clarifications Q1–Q3, Q5). Scripted touches at fixed view sizes (390 × 844, 1,024 × 768,
// 844 × 390) on seeded fixture plays: 500 seeded swipes per view (start angle, radius 40 … 300 points, sweep up to
// ±1.5 turns, 3 … 40 points) send exactly the turn computed here from the screen geometry alone (the centre projected
// through the view-projection, atan2(−dy, dx), the shortest change between successive points, rounding half away from
// zero, wrapping into −47 … 48), with the matching preview after every move; every arbitration case (second finger,
// cancel, tap inside and outside the hub, a moving press, double tap reset and its timing, swipes through and ending in
// the dead zone, winding, every non-playing stage) sends what clarification Q2 says; the orbit follows 90° yaw per view
// width and 60° tilt per view height (upwards towards a top view) and clamps to ±40° and 15° … 60°; the same script
// gives the same results. Plain loops and explicit types (CI type-check rule); seed 2_334.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct HueCompassGestureControllerTests {
    typealias Controller = HueCompassGestureController
    typealias Snapshot = HueCompassSceneSnapshot
    typealias Action = HueCompassGestureAction

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_334
    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_024, 768), Vec2(844, 390)]
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60
    /// Degrees to radians.
    static let degree: Double = Double.pi / 180

    // MARK: Snapshots

    /// A play of fixture `index` begun (playing unless the fixture has a tutorial).
    static func begun(_ index: Int, tutorial: Bool = false) throws -> HueCompassPlay {
        let fixture: HueCompassFixture = HueCompassFixtures.fixture(index, tutorial: tutorial)
        var play: HueCompassPlay = HueCompassPlay(level: fixture.level)
        try play.handle(.begin)
        return play
    }

    /// A playing snapshot of fixture `index`.
    static func playing(_ index: Int) throws -> Snapshot {
        let play: HueCompassPlay = try begun(index)
        #expect(play.stage == .playing)
        return Snapshot(play: play, levelNumber: index + 1, time: 0)
    }

    /// Snapshots in every stage other than playing: loading, tutorial, paused, won, failed and result.
    static func notPlaying() throws -> [Snapshot] {
        var result: [Snapshot] = []
        let fixture: HueCompassFixture = HueCompassFixtures.fixture(0)
        result.append(Snapshot(play: HueCompassPlay(level: fixture.level), levelNumber: 1, time: 0))
        result.append(Snapshot(play: try begun(1, tutorial: true), levelNumber: 2, time: 0))
        var paused: HueCompassPlay = try begun(2)
        try paused.handle(.pause)
        result.append(Snapshot(play: paused, levelNumber: 3, time: 0))
        var won: HueCompassPlay = try begun(0)
        for action in fixture.solution {
            try won.apply(action, expecting: won.fingerprint)
        }
        result.append(Snapshot(play: won, levelNumber: 1, time: 0))
        var shown: HueCompassPlay = won
        try shown.handle(.showResult)
        result.append(Snapshot(play: shown, levelNumber: 1, time: 0))
        var failed: HueCompassPlay = try begun(0)
        let wrong: Int = (fixture.level.target + 48) % 96
        try failed.apply(.select(bearing: wrong, band: 0), expecting: failed.fingerprint)
        result.append(Snapshot(play: failed, levelNumber: 1, time: 0))
        let stages: [HueCompassStage] = [.loading, .tutorial, .paused, .won, .result, .failed]
        var index: Int = 0
        while index < stages.count {
            #expect(result[index].stage == stages[index])
            index += 1
        }
        return result
    }

    // MARK: Independent geometry

    /// The compass centre in view points, projected here through the authored camera's view-projection.
    static func centre(_ view: Vec2) -> Vec2 {
        let camera: HueCompassCamera = HueCompassSceneGeometry.camera(aspect: view.x / view.y)
        let projected: (point: Vec2, depth: Double)? = ScreenProjection.project(Vec3(0, 0, 0),
                                                                              viewProjection: camera.viewProjection,
                                                                              viewport: view)
        return projected?.point ?? Vec2(view.x / 2, view.y / 2)
    }

    /// The angle of `point` about `centre`, counter-clockwise on screen positive, or nil within 20 points.
    static func angle(_ point: Vec2, centre: Vec2) -> Double? {
        let dx: Double = point.x - centre.x
        let up: Double = centre.y - point.y
        if (dx * dx + up * up).squareRoot() < 20 { return nil }
        return atan2(up, dx)
    }

    /// The shortest signed change from `a` to `b` in radians, −π excluded.
    static func change(_ a: Double, _ b: Double) -> Double {
        var d: Double = b - a
        while d > Double.pi { d -= 2 * Double.pi }
        while d <= -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// Whole bearings of `radians`, half away from zero.
    static func bearings(_ radians: Double) -> Int {
        let s: Double = radians * 96 / (2 * Double.pi)
        return s >= 0 ? Int((s + 0.5).rounded(.down)) : -Int((-s + 0.5).rounded(.down))
    }

    /// `steps` into −47 … 48.
    static func wrap(_ steps: Int) -> Int {
        let r: Int = ((steps % 96) + 96) % 96
        return r > 48 ? r - 96 : r
    }

    /// The angle gathered along `points` about `centre`, skipping points in the dead zone.
    static func gathered(_ points: [Vec2], centre: Vec2) -> Double {
        var total: Double = 0
        var last: Double?
        for point in points {
            guard let a = angle(point, centre: centre) else { continue }
            if let previous = last { total += change(previous, a) }
            last = a
        }
        return total
    }

    // MARK: Scripting

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A point at `radius` points and screen angle `radians` (counter-clockwise from +x) about `centre`.
    static func polar(_ centre: Vec2, _ radius: Double, _ radians: Double) -> Vec2 {
        Vec2(centre.x + radius * cos(radians), centre.y - radius * sin(radians))
    }

    /// Plays one finger along `points` (began, moved …, ended) from time `start`; returns every action sent.
    static func swipe(_ controller: inout Controller, _ points: [Vec2], view: Vec2, snapshot: Snapshot,
                      start: Double = 0) -> [Action] {
        var actions: [Action] = []
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            let e: PointerEvent = event(1, phase, points[index], start + Double(index) * frame)
            actions += controller.handle(e, viewSize: view, snapshot: snapshot)
            index += 1
        }
        return actions
    }

    /// A tap (began and ended at `point`) ending at `time`.
    static func tap(_ controller: inout Controller, _ point: Vec2, view: Vec2, snapshot: Snapshot,
                    time: Double) -> [Action] {
        var actions: [Action] = controller.handle(event(1, .began, point, time - 0.05), viewSize: view,
                                                  snapshot: snapshot)
        actions += controller.handle(event(1, .ended, point, time), viewSize: view, snapshot: snapshot)
        return actions
    }

    /// A unit random number 0 ..< 1.
    static func unit(_ random: inout HueCompassRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    /// The hub radius at the authored orbit for `view`.
    static func hub(_ view: Vec2) -> Double {
        HueCompassDial.hubRadius(camera: HueCompassSceneGeometry.camera(aspect: view.x / view.y),
                                 size: SIMD2(view.x, view.y))
    }

    // MARK: Swipes

    @Test func seededSwipesMatchTheIndependentTurn() throws {
        var snapshots: [Snapshot] = []
        var f: Int = 0
        while f < 8 {
            snapshots.append(try Self.playing(f))
            f += 1
        }
        for view in Self.views {
            var random: HueCompassRandom = HueCompassRandom(seed: Self.seed)
            let c: Vec2 = Self.centre(view)
            var turns: Int = 0
            var trial: Int = 0
            while trial < 500 {
                let snapshot: Snapshot = snapshots[trial % snapshots.count]
                let start: Double = Self.unit(&random) * 2 * Double.pi
                let radius: Double = 40 + Self.unit(&random) * 260
                let magnitude: Double = 0.05 + Self.unit(&random) * 1.45
                let sweep: Double = (random.int(0...1) == 0 ? -1 : 1) * magnitude * 2 * Double.pi
                let count: Int = random.int(3...40)
                var points: [Vec2] = []
                var k: Int = 0
                while k < count {
                    points.append(Self.polar(c, radius, start + sweep * Double(k) / Double(count - 1)))
                    k += 1
                }
                let total: Double = Self.gathered(points, centre: c)
                if abs(sweep) / Double(count - 1) < Double.pi - 1e-6 {
                    #expect(abs(total - sweep) < 1e-9)
                }
                let expected: Int = Self.wrap(Self.bearings(total))
                var controller: Controller = Controller()
                var actions: [Action] = []
                var i: Int = 0
                while i < count {
                    let phase: PointerPhase = i == 0 ? .began : (i == count - 1 ? .ended : .moved)
                    actions += controller.handle(Self.event(1, phase, points[i], Double(trial) * 10 + Double(i) * Self.frame),
                                                 viewSize: view, snapshot: snapshot)
                    if phase != .ended {
                        #expect(controller.state == .swiping)
                        var prefix: [Vec2] = []
                        var j: Int = 0
                        while j <= i {
                            prefix.append(points[j])
                            j += 1
                        }
                        let preview: Int = ((snapshot.bearing + Self.bearings(Self.gathered(prefix, centre: c))) % 96 + 96) % 96
                        #expect(controller.previewBearing == preview)
                    }
                    i += 1
                }
                let wanted: [Action] = expected == 0 ? [] : [.turn(expected)]
                #expect(actions == wanted, "view \(view) trial \(trial)")
                #expect(controller.state == .idle)
                #expect(controller.previewBearing == nil)
                if expected != 0 { turns += 1 }
                trial += 1
            }
            #expect(turns > 400)
        }
    }

    @Test func windingWrapsAndDeadZoneAddsNothing() throws {
        let snapshot: Snapshot = try Self.playing(0)
        let view: Vec2 = Self.views[0]
        let c: Vec2 = Self.centre(view)
        // Three quarters of a turn counter-clockwise: 72 bearings, wrapped to −24.
        var points: [Vec2] = []
        var k: Int = 0
        while k <= 12 {
            points.append(Self.polar(c, 120, 1.5 * Double.pi * Double(k) / 12))
            k += 1
        }
        var controller: Controller = Controller()
        #expect(Self.swipe(&controller, points, view: view, snapshot: snapshot) == [.turn(-24)])
        // A swipe through the centre: 30°, then the dead zone, then on to 90°: 24 bearings.
        let through: [Vec2] = [Self.polar(c, 100, 0), Self.polar(c, 100, 30 * Self.degree), Vec2(c.x + 3, c.y + 3),
                               Self.polar(c, 100, 60 * Self.degree), Self.polar(c, 100, 90 * Self.degree)]
        controller = Controller()
        var actions: [Action] = []
        var i: Int = 0
        while i < through.count {
            let phase: PointerPhase = i == 0 ? .began : (i == through.count - 1 ? .ended : .moved)
            actions += controller.handle(Self.event(1, phase, through[i], Double(i) * Self.frame), viewSize: view,
                                         snapshot: snapshot)
            if i == 2 {
                let gathered: Double = controller.accumulatedAngle ?? -1
                #expect(abs(gathered - 30 * Self.degree) < 1e-9)
                #expect(controller.previewBearing == (snapshot.bearing + 8) % 96)
            }
            i += 1
        }
        #expect(actions == [.turn(24)])
        // A swipe ending in the centre keeps the 45° gathered before: 12 bearings clockwise is −12.
        let ending: [Vec2] = [Self.polar(c, 100, 0), Self.polar(c, 100, -45 * Self.degree), c]
        controller = Controller()
        #expect(Self.swipe(&controller, ending, view: view, snapshot: snapshot) == [.turn(-12)])
        // A swipe starting in the centre counts from its first point outside the dead zone.
        let fromCentre: [Vec2] = [c, Self.polar(c, 100, 0), Self.polar(c, 100, 15 * Self.degree)]
        controller = Controller()
        #expect(Self.swipe(&controller, fromCentre, view: view, snapshot: snapshot) == [.turn(4)])
        // A swipe back to where it started gathers nothing and sends nothing.
        let back: [Vec2] = [Self.polar(c, 100, 0), Self.polar(c, 100, 40 * Self.degree), Self.polar(c, 100, 0)]
        controller = Controller()
        #expect(Self.swipe(&controller, back, view: view, snapshot: snapshot) == [])
    }

    // MARK: Taps

    @Test func tapsProbeInTheHubOnly() throws {
        let snapshot: Snapshot = try Self.playing(3)
        for view in Self.views {
            let c: Vec2 = Self.centre(view)
            let hub: Double = Self.hub(view)
            #expect(hub >= 30)
            var controller: Controller = Controller()
            #expect(Self.tap(&controller, c, view: view, snapshot: snapshot, time: 1) == [.probe])
            #expect(Self.tap(&controller, Self.polar(c, hub - 1, 1.0), view: view, snapshot: snapshot,
                             time: 2) == [.probe])
            // A press that wobbles less than 10 points is still a tap.
            var actions: [Action] = controller.handle(Self.event(1, .began, c, 3), viewSize: view, snapshot: snapshot)
            actions += controller.handle(Self.event(1, .moved, Vec2(c.x + 6, c.y + 5), 3.05), viewSize: view,
                                         snapshot: snapshot)
            actions += controller.handle(Self.event(1, .ended, Vec2(c.x + 2, c.y), 3.1), viewSize: view,
                                         snapshot: snapshot)
            #expect(actions == [.probe])
            // On the wheel, outside the hub: nothing.
            let ring: SIMD2<Double>? = HueCompassDial.point(SIMD3(0.75, 0, 0),
                                                            camera: HueCompassSceneGeometry.camera(aspect: view.x / view.y),
                                                            size: SIMD2(view.x, view.y))
            let onWheel: Vec2 = Vec2(ring?.x ?? 0, ring?.y ?? 0)
            #expect((onWheel - c).length > hub)
            #expect(Self.tap(&controller, onWheel, view: view, snapshot: snapshot, time: 4) == [])
            #expect(Self.tap(&controller, onWheel, view: view, snapshot: snapshot, time: 4.1) == [])
            // A press in the hub that moves 10 points or more is a swipe, never a probe.
            var moving: [Action] = controller.handle(Self.event(1, .began, c, 5), viewSize: view, snapshot: snapshot)
            moving += controller.handle(Self.event(1, .moved, Vec2(c.x + 12, c.y), 5.05), viewSize: view,
                                        snapshot: snapshot)
            moving += controller.handle(Self.event(1, .ended, Vec2(c.x + 1, c.y), 5.1), viewSize: view,
                                        snapshot: snapshot)
            #expect(!moving.contains(.probe))
            #expect(controller.state == .idle)
        }
    }

    @Test func doubleTapOnEmptySpaceResetsTheView() throws {
        let snapshot: Snapshot = try Self.playing(4)
        for view in Self.views {
            let corner: Vec2 = Vec2(8, 8)
            let other: Vec2 = Vec2(view.x - 8, view.y - 8)
            let camera: HueCompassCamera = HueCompassSceneGeometry.camera(aspect: view.x / view.y)
            #expect(Controller.outsideWheel(corner, camera: camera, size: SIMD2(view.x, view.y)))
            #expect(Controller.outsideWheel(other, camera: camera, size: SIMD2(view.x, view.y)))
            #expect(!Controller.outsideWheel(Self.centre(view), camera: camera, size: SIMD2(view.x, view.y)))
            var controller: Controller = Controller()
            Self.orbit(&controller, by: Vec2(view.x * 0.2, view.y * 0.2), view: view, snapshot: snapshot, time: 0)
            #expect(controller.orbit != .authored)
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 1) == [])
            #expect(Self.tap(&controller, other, view: view, snapshot: snapshot, time: 1.3) == [.resetView])
            #expect(controller.orbit == .authored)
            // The pair is used up: a third tap soon after does not reset again.
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 1.5) == [])
            // Taps more than 0.35 s apart do not reset.
            controller = Controller()
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 10) == [])
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 10.4) == [])
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 10.7) == [.resetView])
            // A tap on the wheel or in the hub between them breaks the pair.
            controller = Controller()
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 20) == [])
            #expect(Self.tap(&controller, Self.centre(view), view: view, snapshot: snapshot, time: 20.1) == [.probe])
            #expect(Self.tap(&controller, corner, view: view, snapshot: snapshot, time: 20.2) == [])
            // The panel's reset.
            Self.orbit(&controller, by: Vec2(-view.x * 0.1, 0), view: view, snapshot: snapshot, time: 30)
            #expect(controller.orbit != .authored)
            controller.resetView()
            #expect(controller.orbit == .authored)
        }
    }

    // MARK: Arbitration

    @Test func secondFingerCancelsTheSwipeAndOrbits() throws {
        let snapshot: Snapshot = try Self.playing(5)
        let view: Vec2 = Self.views[1]
        let c: Vec2 = Self.centre(view)
        var controller: Controller = Controller()
        var actions: [Action] = []
        actions += controller.handle(Self.event(1, .began, Self.polar(c, 150, 0), 0), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(1, .moved, Self.polar(c, 150, 1.0), 0.1), viewSize: view,
                                     snapshot: snapshot)
        #expect(controller.previewBearing != nil)
        actions += controller.handle(Self.event(2, .began, Vec2(100, 100), 0.2), viewSize: view, snapshot: snapshot)
        #expect(controller.state == .orbiting)
        #expect(controller.previewBearing == nil)
        actions += controller.handle(Self.event(1, .moved, Self.polar(c, 150, 2.0), 0.3), viewSize: view,
                                     snapshot: snapshot)
        actions += controller.handle(Self.event(2, .moved, Vec2(140, 100), 0.3), viewSize: view, snapshot: snapshot)
        #expect(controller.orbit != .authored)
        actions += controller.handle(Self.event(1, .ended, Self.polar(c, 150, 2.0), 0.4), viewSize: view,
                                     snapshot: snapshot)
        #expect(controller.state == .cancelled)
        actions += controller.handle(Self.event(2, .moved, Vec2(300, 300), 0.5), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(2, .ended, Vec2(300, 300), 0.6), viewSize: view, snapshot: snapshot)
        #expect(actions == [])
        #expect(controller.state == .idle)
        // A new swipe afterwards works again.
        let next: [Vec2] = [Self.polar(c, 150, 0), Self.polar(c, 150, 15 * Self.degree)]
        #expect(Self.swipe(&controller, next, view: view, snapshot: snapshot, start: 1) == [.turn(4)])
    }

    @Test func cancelledTouchesSendNothing() throws {
        let snapshot: Snapshot = try Self.playing(6)
        let view: Vec2 = Self.views[2]
        let c: Vec2 = Self.centre(view)
        var controller: Controller = Controller()
        var actions: [Action] = []
        actions += controller.handle(Self.event(1, .began, Self.polar(c, 120, 0), 0), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(1, .moved, Self.polar(c, 120, 1.2), 0.1), viewSize: view,
                                     snapshot: snapshot)
        actions += controller.handle(Self.event(1, .cancelled, Self.polar(c, 120, 1.2), 0.2), viewSize: view,
                                     snapshot: snapshot)
        #expect(controller.state == .idle)
        #expect(controller.previewBearing == nil)
        // A cancelled press in the hub does not probe.
        actions += controller.handle(Self.event(1, .began, c, 1), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(1, .cancelled, c, 1.05), viewSize: view, snapshot: snapshot)
        // A cancelled orbit.
        actions += controller.handle(Self.event(1, .began, Vec2(100, 100), 2), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(2, .began, Vec2(200, 100), 2.1), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(1, .cancelled, Vec2(100, 100), 2.2), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(2, .cancelled, Vec2(200, 100), 2.2), viewSize: view, snapshot: snapshot)
        // Unknown pointers and non-finite points.
        actions += controller.handle(Self.event(9, .ended, c, 3), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(9, .moved, c, 3), viewSize: view, snapshot: snapshot)
        actions += controller.handle(Self.event(9, .began, Vec2(Double.nan, 1), 3), viewSize: view, snapshot: snapshot)
        #expect(actions == [])
        #expect(controller.state == .idle)
        // An unusable view sends nothing.
        let flat: Vec2 = Vec2(0, 0)
        #expect(Self.tap(&controller, Vec2(0, 0), view: flat, snapshot: snapshot, time: 5) == [])
        let swipe: [Vec2] = [Vec2(10, 10), Vec2(200, 10), Vec2(200, 200)]
        #expect(Self.swipe(&controller, swipe, view: flat, snapshot: snapshot, start: 6) == [])
    }

    @Test func notPlayingStagesNeverTurnOrProbe() throws {
        for snapshot in try Self.notPlaying() {
            for view in Self.views {
                let c: Vec2 = Self.centre(view)
                var controller: Controller = Controller()
                var actions: [Action] = []
                var k: Int = 0
                while k <= 6 {
                    let phase: PointerPhase = k == 0 ? .began : (k == 6 ? .ended : .moved)
                    actions += controller.handle(Self.event(1, phase, Self.polar(c, 140, Double(k) * 0.3), Double(k) * 0.02),
                                                 viewSize: view, snapshot: snapshot)
                    #expect(controller.previewBearing == nil)
                    k += 1
                }
                actions += Self.tap(&controller, c, view: view, snapshot: snapshot, time: 1)
                #expect(actions == [], "stage \(snapshot.stage)")
                Self.orbit(&controller, by: Vec2(view.x * 0.1, 0), view: view, snapshot: snapshot, time: 2)
                #expect(controller.orbit != .authored)
                #expect(Self.tap(&controller, Vec2(8, 8), view: view, snapshot: snapshot, time: 3) == [])
                #expect(Self.tap(&controller, Vec2(8, 8), view: view, snapshot: snapshot, time: 3.2) == [.resetView])
                #expect(controller.orbit == .authored)
            }
        }
    }

    // MARK: Orbit

    /// Two fingers moving together by `delta` in ten steps, from the middle of the view.
    static func orbit(_ controller: inout Controller, by delta: Vec2, view: Vec2, snapshot: Snapshot, time: Double) {
        let a: Vec2 = Vec2(view.x * 0.4, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.6, view.y * 0.5)
        _ = controller.handle(event(11, .began, a, time), viewSize: view, snapshot: snapshot)
        _ = controller.handle(event(12, .began, b, time + 0.01), viewSize: view, snapshot: snapshot)
        var step: Int = 1
        while step <= 10 {
            let s: Vec2 = delta * (Double(step) / 10)
            _ = controller.handle(event(11, .moved, a + s, time + 0.02 * Double(step)), viewSize: view,
                                  snapshot: snapshot)
            _ = controller.handle(event(12, .moved, b + s, time + 0.02 * Double(step)), viewSize: view,
                                  snapshot: snapshot)
            step += 1
        }
        _ = controller.handle(event(11, .ended, a + delta, time + 0.3), viewSize: view, snapshot: snapshot)
        _ = controller.handle(event(12, .ended, b + delta, time + 0.3), viewSize: view, snapshot: snapshot)
    }

    @Test func orbitFollowsRatesAndLimits() throws {
        let snapshot: Snapshot = try Self.playing(7)
        for view in Self.views {
            var controller: Controller = Controller()
            let authored: HueCompassOrbit = .authored
            // A tenth of the width to the right: +9° yaw; a tenth of the height upwards: −6° tilt (towards a top view).
            Self.orbit(&controller, by: Vec2(view.x * 0.1, 0), view: view, snapshot: snapshot, time: 0)
            #expect(abs(controller.orbit.yaw - 9 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.tilt - authored.tilt) < 1e-12)
            Self.orbit(&controller, by: Vec2(0, -view.y * 0.1), view: view, snapshot: snapshot, time: 1)
            #expect(abs(controller.orbit.tilt - 29 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.yaw - 9 * Self.degree) < 1e-9)
            #expect(controller.state == .idle)
            // Limits: far right and far up clamp to +40° and 15°; far left and down to −40° and 60°.
            Self.orbit(&controller, by: Vec2(view.x * 3, -view.y * 3), view: view, snapshot: snapshot, time: 2)
            #expect(abs(controller.orbit.yaw - 40 * Self.degree) < 1e-12)
            #expect(abs(controller.orbit.tilt - 15 * Self.degree) < 1e-12)
            // Clamping happens per step, so turning back responds at once.
            Self.orbit(&controller, by: Vec2(-view.x * 0.1, view.y * 0.1), view: view, snapshot: snapshot, time: 3)
            #expect(abs(controller.orbit.yaw - 31 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.tilt - 21 * Self.degree) < 1e-9)
            Self.orbit(&controller, by: Vec2(-view.x * 3, view.y * 3), view: view, snapshot: snapshot, time: 4)
            #expect(abs(controller.orbit.yaw + 40 * Self.degree) < 1e-12)
            #expect(abs(controller.orbit.tilt - 60 * Self.degree) < 1e-12)
            // A third finger re-bases the midpoint: the camera does not jump.
            controller.resetView()
            _ = controller.handle(Self.event(11, .began, Vec2(100, 100), 5), viewSize: view, snapshot: snapshot)
            _ = controller.handle(Self.event(12, .began, Vec2(200, 100), 5), viewSize: view, snapshot: snapshot)
            _ = controller.handle(Self.event(13, .began, Vec2(300, 300), 5), viewSize: view, snapshot: snapshot)
            #expect(controller.orbit == .authored)
            _ = controller.handle(Self.event(13, .moved, Vec2(300, 300), 5.1), viewSize: view, snapshot: snapshot)
            #expect(controller.orbit == .authored)
            // One finger alone never orbits.
            var single: Controller = Controller()
            let c: Vec2 = Self.centre(view)
            _ = Self.swipe(&single, [Self.polar(c, 100, 0), Self.polar(c, 100, 2), Vec2(5, 5)], view: view,
                           snapshot: snapshot)
            #expect(single.orbit == .authored)
        }
    }

    // MARK: Determinism

    @Test func sameScriptSameResults() throws {
        let snapshot: Snapshot = try Self.playing(2)
        let view: Vec2 = Self.views[0]
        var random: HueCompassRandom = HueCompassRandom(seed: Self.seed)
        var script: [PointerEvent] = []
        var time: Double = 0
        var n: Int = 0
        while n < 200 {
            let id: Int = 1 + random.int(0...1)
            let kind: Int = random.int(0...3)
            let phase: PointerPhase = kind == 0 ? .began : (kind == 1 ? .ended : (kind == 2 ? .moved : .moved))
            let point: Vec2 = Vec2(Self.unit(&random) * view.x, Self.unit(&random) * view.y)
            time += Self.unit(&random) * 0.3
            script.append(Self.event(id, phase, point, time))
            n += 1
        }
        var first: Controller = Controller()
        var second: Controller = Controller()
        var a: [Action] = []
        var b: [Action] = []
        for e in script {
            a += first.handle(e, viewSize: view, snapshot: snapshot)
            b += second.handle(e, viewSize: view, snapshot: snapshot)
            #expect(first.previewBearing == second.previewBearing)
            #expect(first.state == second.state)
        }
        #expect(a == b)
        #expect(first.orbit == second.orbit)
        #expect(a.count <= 200)
    }
}
