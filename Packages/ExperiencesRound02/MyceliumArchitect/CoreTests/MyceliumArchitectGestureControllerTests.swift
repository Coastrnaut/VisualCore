// MyceliumArchitectGestureControllerTests — feature 514 (R02-G22-04) T-R02G2204-004 (FR-R02G2204-001 … 006, 008, 009,
// 010, 012; SC-R02G2204-001, 002, 003, 006; clarifications Q2–Q5). The gesture controller driven by scripted pointer
// sequences on certified levels at several orbits: taps on empty sites place the tool's item and taps on placed items
// clear them (one `.send` each, previewed at touch-down), longer presses commit and 16-point drags cancel the preview,
// taps on other cells inspect and a second tap clears, seed drags from the root send the direction under the finger
// (an independent cast with the picker's contract) and short ones nothing, unseed drags send only when released on the
// root, the root and sprouts explain when tapped, gauge presses and scrubs show the pulse under the finger and never
// change the digest, second fingers and cancels clear the preview and send nothing, gestures outside playing send no
// kernel action and give the stage's reason, a double tap on empty space resets the view, unusable input is empty
// space, 200 seeded previews (seed 2_514) equal the kernel's report of the changed arrangement or its refusal, and a
// refused change is sent once and refused by the adapter with the kernel's reason code. Touch points are found through
// `MyceliumArchitectPicker.pick` only (the contract), so the tests hold for any picker satisfying it. Host-run
// (`swift test`); explicit types, plain loops (CI type-check rule). Modelled on `BinaryGardensGestureControllerTests`
// (feature 504).
import Foundation
@testable import MyceliumArchitectCore
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// A deterministic SplitMix64 generator for the seeded cases.
private struct GestureRandom {
    /// The generator state.
    var state: UInt64

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A whole number 0 ..< `bound` (`bound` > 0).
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

/// A scripted pointer sequence against one controller.
private struct GestureScript {
    /// The controller under test.
    var controller: MyceliumArchitectGestureController = MyceliumArchitectGestureController()
    /// The current event timestamp in seconds.
    var time: Double = 100
    /// The drawn snapshot passed with every event.
    var snapshot: MyceliumArchitectSceneSnapshot
    /// The view size in points.
    var viewSize: Vec2
    /// The tool passed with every event.
    var tool: MyceliumArchitectTool
    /// The orbit passed with every event.
    var orbit: MyceliumArchitectViewOrbit

    /// A script for `snapshot` in a view of `viewSize` with `tool` at `orbit`.
    init(snapshot: MyceliumArchitectSceneSnapshot, viewSize: Vec2, tool: MyceliumArchitectTool = .nutrient,
         orbit: MyceliumArchitectViewOrbit = .authored) {
        self.snapshot = snapshot
        self.viewSize = viewSize
        self.tool = tool
        self.orbit = orbit
    }

    /// Sends one event of pointer `id` in `phase` at `point`, `dt` seconds after the previous one.
    mutating func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2,
                        dt: Double = 0.02) -> [MyceliumArchitectGestureAction] {
        time += dt
        let e: PointerEvent = PointerEvent(id: id, phase: phase, location: point, timestamp: time)
        let actions: [MyceliumArchitectGestureAction] = controller.handle(e, viewSize: viewSize, snapshot: snapshot,
                                                                          tool: tool, orbit: orbit)
        // As the presenter does: a turned orbit is stored and passed with the next event.
        for action in actions {
            if case .orbit(let turned) = action { orbit = turned }
        }
        return actions
    }

    /// A tap at `point` held `held` seconds.
    mutating func tap(_ point: Vec2, held: Double = 0.1) -> [MyceliumArchitectGestureAction] {
        let down: [MyceliumArchitectGestureAction] = event(1, .began, point, dt: 0.6)
        return down + event(1, .ended, point, dt: held)
    }

    /// A drag of pointer 1 from `from` to `to` in `steps` moves, released at `to`.
    mutating func drag(_ from: Vec2, _ to: Vec2, steps: Int = 8) -> [MyceliumArchitectGestureAction] {
        var actions: [MyceliumArchitectGestureAction] = event(1, .began, from, dt: 0.6)
        for step in 1...steps {
            let t: Double = Double(step) / Double(steps)
            let p: Vec2 = Vec2(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t)
            actions += event(1, .moved, p)
        }
        actions += event(1, .ended, to)
        return actions
    }
}

@Suite struct MyceliumArchitectGestureControllerTests {
    typealias Controller = MyceliumArchitectGestureController
    typealias Action = MyceliumArchitectGestureAction
    typealias Core = MyceliumArchitectExperienceCore
    typealias Cell = MyceliumArchitectCell
    typealias Target = MyceliumArchitectPickTarget

    /// The seed of every seeded test of this feature.
    static let seed: UInt64 = 2_514
    /// A phone-sized portrait view.
    static let phone: Vec2 = Vec2(390, 844)
    /// A tablet-sized landscape view.
    static let tablet: Vec2 = Vec2(1180, 820)
    /// The orbits the tests use: authored, two turned ones within bounds.
    static let orbits: [MyceliumArchitectViewOrbit] = [
        .authored, MyceliumArchitectViewOrbit(yaw: 0.45, pitch: 0.3), MyceliumArchitectViewOrbit(yaw: -0.6, pitch: -0.2),
    ]

    /// The opening of level `number`.
    static func core(_ number: Int) throws -> Core { try Core.opening(number: number) }

    /// `core` after `control` with `values`, which must be accepted.
    static func accepted(_ core: Core, _ control: String, _ values: [Double] = []) -> Core {
        var next: Core = core
        let result: ActionResult = next.apply(ExperienceAction(control: control, values: values, step: 0))
        #expect(result.isAccepted, "\(control) \(values): \(result.code)")
        return next
    }

    /// The digest of `core` as written by the adapter.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// One view point per pick target of `snapshot` in a view of `viewSize` at `orbit`: of the grid points (every
    /// `step` points) that pick the target, the one nearest their centroid. Found through the picker's contract only.
    static func points(_ snapshot: MyceliumArchitectSceneSnapshot, viewSize: Vec2, orbit: MyceliumArchitectViewOrbit,
                       step: Double = 4) -> [Target: Vec2] {
        var hits: [Target: [Vec2]] = [:]
        var y: Double = step / 2
        while y < viewSize.y {
            var x: Double = step / 2
            while x < viewSize.x {
                let p: Vec2 = Vec2(x, y)
                let target: Target = MyceliumArchitectPicker.pick(p, viewSize: viewSize, snapshot: snapshot,
                                                                  orbit: orbit)
                hits[target, default: []].append(p)
                x += step
            }
            y += step
        }
        var result: [Target: Vec2] = [:]
        for (target, list) in hits {
            var sx: Double = 0
            var sy: Double = 0
            for p in list {
                sx += p.x
                sy += p.y
            }
            let centroid: Vec2 = Vec2(sx / Double(list.count), sy / Double(list.count))
            var best: Vec2 = list[0]
            var bestDistance: Double = Double.infinity
            for p in list {
                let d: Double = (p - centroid).length
                if d < bestDistance {
                    bestDistance = d
                    best = p
                }
            }
            result[target] = best
        }
        return result
    }

    /// The `.send` actions of `actions` as (control, values).
    static func sends(_ actions: [Action]) -> [(control: String, values: [Double])] {
        var result: [(control: String, values: [Double])] = []
        for action in actions {
            if case .send(let control, let values) = action { result.append((control, values)) }
        }
        return result
    }

    /// The previews of `actions`.
    static func previews(_ actions: [Action]) -> [MyceliumArchitectAction] {
        var result: [MyceliumArchitectAction] = []
        for action in actions {
            if case .preview(let change) = action { result.append(change) }
        }
        return result
    }

    /// The kernel's own judgement of `change` on `core`'s play, computed independently of the adapter: `.stage`
    /// outside playing, the change rule's refusal, `.budget` with no action left, else the growth report of the changed
    /// arrangement.
    static func kernelPreview(_ core: Core,
                              _ change: MyceliumArchitectAction) -> Result<MyceliumArchitectReport, MyceliumArchitectError> {
        let play: MyceliumArchitectPlay = core.play
        guard play.stage == .playing else { return .failure(.stage) }
        let next: MyceliumArchitectArrangement
        do throws(MyceliumArchitectError) {
            next = try MyceliumArchitectPlay.changed(play.level, play.arrangement, by: change)
        } catch {
            return .failure(error)
        }
        guard play.actionsLeft > 0 else { return .failure(.budget) }
        return .success(MyceliumArchitectGrowth.report(play.level, arrangement: next))
    }

    /// The expected change of a press on `cell` with `tool` while playing (independent of the controller): `.clear`
    /// on a placed item, the tool's placement on an empty site, nil otherwise.
    static func expectedChange(_ cell: Cell, _ snapshot: MyceliumArchitectSceneSnapshot,
                               _ tool: MyceliumArchitectTool) -> MyceliumArchitectAction? {
        let a: MyceliumArchitectArrangement = snapshot.arrangement
        if a.nutrients.contains(cell) || a.blockers.contains(cell) { return .clear(cell) }
        if snapshot.level.isSite(cell) && snapshot.level.isEmpty(cell, in: a) {
            return tool == .nutrient ? .nutrient(cell) : .blocker(cell)
        }
        return nil
    }

    /// The values of `cell`.
    static func values(_ cell: Cell) -> [Double] { [Double(cell.column), Double(cell.row)] }

    /// The first empty site of `snapshot` whose view point is known in `map`.
    static func emptySite(_ snapshot: MyceliumArchitectSceneSnapshot, _ map: [Target: Vec2],
                          skipping: [Cell] = []) -> (cell: Cell, point: Vec2)? {
        for cell in snapshot.level.sites ?? [] where !skipping.contains(cell) {
            guard snapshot.level.isEmpty(cell, in: snapshot.arrangement), let p = map[.cell(cell)] else { continue }
            return (cell, p)
        }
        return nil
    }

    /// A cell of `snapshot` that is neither a site nor placed (a press inspects it), with its view point.
    static func plainCell(_ snapshot: MyceliumArchitectSceneSnapshot, _ map: [Target: Vec2]) -> (cell: Cell, point: Vec2)? {
        for row in 0..<snapshot.level.height {
            for column in 0..<snapshot.level.width {
                let cell: Cell = Cell(column: column, row: row)
                guard expectedChange(cell, snapshot, .nutrient) == nil, let p = map[.cell(cell)] else { continue }
                return (cell, p)
            }
        }
        return nil
    }

    // MARK: Constants

    @Test func constantsEqualFeature504() {
        #expect(Controller.tapDistance == 10)
        #expect(Controller.dragDistance == 16)
        #expect(Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35)
        #expect(Controller.doubleTapDistance == 22)
        #expect(abs(Controller.yawPerViewWidth - Double.pi / 2) < 1e-15)
        #expect(abs(Controller.pitchPerViewHeight - Double.pi / 3) < 1e-15)
        #expect(Controller.seedTravel == 0.5)
        #expect(Controller.finishedReason == "The play is over: undo or go to the next level")
        #expect(Controller.notRunningReason == "The level is not being played")
        #expect(!Controller.rootReason.isEmpty && !Controller.sproutReason.isEmpty)
        #expect(Controller.stageReason(.won) == Controller.finishedReason)
        #expect(Controller.stageReason(.failed) == Controller.finishedReason)
        #expect(Controller.stageReason(.result) == Controller.finishedReason)
        #expect(Controller.stageReason(.paused) == Controller.notRunningReason)
        #expect(Controller.stageReason(.loading) == Controller.notRunningReason)
        #expect(Controller.stageReason(.tutorial) == Controller.notRunningReason)
        #expect(Controller.send(.run) == nil)
        #expect(Controller.send(.seed(.east)) == .send("root.seed", [2]))
    }

    // MARK: Sites (FR-001, 002)

    @Test func tapOnEmptySiteSendsTheToolsPlacementOnce() throws {
        let core: Core = try Self.core(1)
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        for orbit in Self.orbits {
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: orbit)
            let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map))
            for tool in MyceliumArchitectTool.allCases {
                var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, tool: tool,
                                                          orbit: orbit)
                let down: [Action] = script.event(1, .began, site.point, dt: 1)
                let change: MyceliumArchitectAction = tool == .nutrient ? .nutrient(site.cell) : .blocker(site.cell)
                #expect(down == [.preview(change)])
                #expect(script.controller.state == .sitePress)
                let up: [Action] = script.event(1, .ended, site.point, dt: 0.1)
                let control: String = tool == .nutrient ? "cell.nutrient" : "cell.blocker"
                #expect(up == [.send(control, Self.values(site.cell)), .clearPreview])
                #expect(script.controller.state == .idle)
                let next: Core = Self.accepted(core, control, Self.values(site.cell))
                #expect(next.play.actionsSpent == 1)
            }
        }
    }

    @Test func tapOnPlacedItemSendsOneClear() throws {
        let opening: Core = try Self.core(1)
        let first: MyceliumArchitectSceneSnapshot = opening.snapshot(time: 0)
        let map0: [Target: Vec2] = Self.points(first, viewSize: Self.phone, orbit: .authored)
        let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(first, map0))
        let placed: Core = Self.accepted(opening, "cell.blocker", Self.values(site.cell))
        let snapshot: MyceliumArchitectSceneSnapshot = placed.snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let point: Vec2 = try #require(map[.cell(site.cell)])
        for tool in MyceliumArchitectTool.allCases {
            var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, tool: tool)
            let actions: [Action] = script.tap(point)
            #expect(actions == [.preview(.clear(site.cell)), .send("cell.clear", Self.values(site.cell)), .clearPreview])
        }
        let cleared: Core = Self.accepted(placed, "cell.clear", Self.values(site.cell))
        #expect(cleared.play.arrangement.blockers.isEmpty)
    }

    @Test func longPressCommitsAndDragCancelsThePreview() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map))
        // A press held 0.9 s with 12 points of travel still commits (under 16 points).
        var held: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var actions: [Action] = held.event(1, .began, site.point, dt: 1)
        actions += held.event(1, .moved, Vec2(site.point.x + 12, site.point.y), dt: 0.4)
        actions += held.event(1, .ended, Vec2(site.point.x + 12, site.point.y), dt: 0.5)
        #expect(actions == [.preview(.nutrient(site.cell)), .send("cell.nutrient", Self.values(site.cell)), .clearPreview])
        // Moving 16 points cancels the preview once; the release sends nothing, even back over the cell.
        var moved: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var drag: [Action] = moved.event(1, .began, site.point, dt: 1)
        drag += moved.event(1, .moved, Vec2(site.point.x, site.point.y + 16))
        #expect(drag == [.preview(.nutrient(site.cell)), .clearPreview])
        drag = moved.event(1, .moved, site.point)
        drag += moved.event(1, .ended, site.point)
        #expect(drag.isEmpty)
        #expect(moved.controller.state == .idle)
    }

    // MARK: Inspection (FR-005)

    @Test func tapInspectsACellAndASecondTapClears() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        for orbit in Self.orbits {
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.tablet, orbit: orbit, step: 6)
            let plain: (cell: Cell, point: Vec2) = try #require(Self.plainCell(snapshot, map))
            var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.tablet, orbit: orbit)
            #expect(script.tap(plain.point) == [.inspect(plain.cell)])
            script.snapshot = snapshot.inspecting(plain.cell)
            #expect(script.tap(plain.point) == [.inspect(nil)])
            // A long press or a drag on the cell inspects nothing.
            #expect(script.tap(plain.point, held: 0.6).isEmpty)
            #expect(script.drag(plain.point, Vec2(plain.point.x + 30, plain.point.y)).isEmpty)
        }
    }

    // MARK: Seeds (FR-003)

    @Test func seedDragSendsTheDirectionUnderTheFinger() throws {
        let core: Core = try Self.core(22)
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        let level: MyceliumArchitectLevel = snapshot.level
        var checked: Int = 0
        for orbit in Self.orbits {
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: orbit)
            let root: Vec2 = try #require(map[.root])
            for direction in MyceliumArchitectDirection.allCases {
                let cell: Cell = Cell(column: level.root.column + 3 * direction.offset.column,
                                      row: level.root.row + 3 * direction.offset.row)
                guard level.contains(cell), let end = map[.cell(cell)] else { continue }
                var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, orbit: orbit)
                let actions: [Action] = script.drag(root, end)
                let start: Vec2 = try #require(MyceliumArchitectPicker.cast(root, viewSize: Self.phone, orbit: orbit))
                let finish: Vec2 = try #require(MyceliumArchitectPicker.cast(end, viewSize: Self.phone, orbit: orbit))
                let expected: MyceliumArchitectDirection = MyceliumArchitectPicker.direction(from: start, to: finish)
                #expect(expected == direction, "\(direction) at \(orbit)")
                let sent: [(control: String, values: [Double])] = Self.sends(actions)
                #expect(sent.count == 1)
                #expect(sent.first?.control == "root.seed")
                #expect(sent.first?.values == [Double(expected.rawValue)])
                #expect(Self.previews(actions).last == .seed(expected))
                #expect(actions.last == .clearPreview)
                checked += 1
            }
        }
        #expect(checked >= 9)
        // Out 20 points and back to the root: under 0.5 · s of cast travel, nothing is sent.
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let root: Vec2 = try #require(map[.root])
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var actions: [Action] = script.event(1, .began, root, dt: 1)
        actions += script.event(1, .moved, Vec2(root.x + 20, root.y))
        #expect(script.controller.state == .seedDrag)
        actions += script.event(1, .moved, Vec2(root.x + 1, root.y))
        actions += script.event(1, .ended, Vec2(root.x + 1, root.y))
        #expect(Self.sends(actions).isEmpty)
        #expect(Self.previews(actions).count >= 1)
        #expect(actions.last == .clearPreview)
    }

    @Test func unseedDragSendsOnlyWhenReleasedOnTheRoot() throws {
        let opening: Core = try Self.core(22)
        let level: MyceliumArchitectLevel = opening.play.level
        var seeded: Core? = nil
        var direction: MyceliumArchitectDirection = .north
        for candidate in MyceliumArchitectDirection.allCases {
            let cell: Cell = Cell(column: level.root.column + 3 * candidate.offset.column,
                                  row: level.root.row + 3 * candidate.offset.row)
            guard level.contains(cell) else { continue }
            seeded = Self.accepted(opening, "root.seed", [Double(candidate.rawValue)])
            direction = candidate
            break
        }
        let core: Core = try #require(seeded)
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let sprout: Vec2 = try #require(map[.sprout(direction)])
        let root: Vec2 = try #require(map[.root])
        let far: Cell = Cell(column: level.root.column + 3 * direction.offset.column,
                             row: level.root.row + 3 * direction.offset.row)
        let away: Vec2 = try #require(map[.cell(far)])
        // Out to a far cell first so the drag starts, then back onto the root.
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var actions: [Action] = script.event(1, .began, sprout, dt: 1)
        #expect(script.controller.state == .sproutPress)
        actions += script.event(1, .moved, away)
        #expect(script.controller.state == .unseedDrag)
        actions += script.event(1, .moved, root)
        actions += script.event(1, .ended, root)
        #expect(actions == [.preview(.unseed(direction)), .send("root.unseed", [Double(direction.rawValue)]),
                            .clearPreview])
        // Released away from the root: nothing is sent.
        var missed: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        let none: [Action] = missed.drag(sprout, away)
        #expect(none == [.preview(.unseed(direction)), .clearPreview])
        let back: Core = Self.accepted(core, "root.unseed", [Double(direction.rawValue)])
        #expect(back.play.arrangement.seeds.isEmpty)
    }

    @Test func startingSeedUnseedIsSentOnceAndRefused() throws {
        let core: Core = try Self.core(21)
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        let start: MyceliumArchitectDirection = try #require(snapshot.level.startSeeds.first)
        var found: Int = 0
        for orbit in Self.orbits {
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: orbit)
            guard let sprout = map[.sprout(start)], let root = map[.root] else { continue }
            var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, orbit: orbit)
            var actions: [Action] = script.event(1, .began, sprout, dt: 1)
            actions += script.event(1, .moved, Vec2(sprout.x, sprout.y - 60))
            actions += script.event(1, .moved, root)
            actions += script.event(1, .ended, root)
            #expect(Self.previews(actions) == [.unseed(start)])
            let sent: [(control: String, values: [Double])] = Self.sends(actions)
            #expect(sent.count == 1)
            #expect(core.previewReport(.unseed(start)) == .failure(.action("starting seed")))
            var refused: Core = core
            let result: ActionResult = refused.apply(ExperienceAction(control: sent[0].control, values: sent[0].values,
                                                                      step: 0))
            #expect(!result.isAccepted && result.code == "action.rule.r02-g22.action")
            #expect(try Self.digest(refused) == Self.digest(core))
            found += 1
        }
        #expect(found >= 1)
    }

    @Test func tapsOnTheRootAndASproutExplain() throws {
        let core: Core = try Self.core(21)
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let root: Vec2 = try #require(map[.root])
        let start: MyceliumArchitectDirection = try #require(snapshot.level.startSeeds.first)
        let sprout: Vec2 = try #require(map[.sprout(start)])
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        #expect(script.tap(root) == [.explain(Controller.rootReason)])
        #expect(script.tap(sprout) == [.explain(Controller.sproutReason)])
        #expect(script.tap(root, held: 0.7).isEmpty)
    }

    // MARK: Gauge (FR-004)

    @Test func gaugePressesAndScrubsShowThePulseAndNeverChangeTheDigest() throws {
        let opening: Core = try Self.core(1)
        let failed: Core = Self.accepted(opening, "growth.run")
        for core in [opening, failed] {
            let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
            for orbit in Self.orbits {
                let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: orbit)
                let centre: Vec2 = try #require(map[.gauge])
                // Points along the projected plate's axis (it slants under a yawed or pitched orbit), left to right.
                let camera: MyceliumArchitectCamera = try #require(
                    MyceliumArchitectPicker.camera(viewSize: Self.phone, orbit: orbit))
                var along: [Vec2] = []
                var step: Int = 0
                while step <= 188 {
                    let world: SIMD3<Double> = SIMD3<Double>(-0.94 + 0.01 * Double(step), -1.12, 0)
                    step += 1
                    guard let p = MyceliumArchitectPicker.viewPoint(world, viewSize: Self.phone, camera: camera) else {
                        continue
                    }
                    if MyceliumArchitectPicker.pick(p, viewSize: Self.phone, snapshot: snapshot, orbit: orbit) == .gauge {
                        along.append(p)
                    }
                }
                #expect(along.count >= 20, "\(along.count) at \(orbit)")
                // A tap shows the pulse under the finger.
                var tapper: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, orbit: orbit)
                let plane: Vec2 = try #require(MyceliumArchitectPicker.cast(centre, viewSize: Self.phone, orbit: orbit))
                let pulse: Int = MyceliumArchitectPicker.pulse(atPlaneX: plane.x, pulsesRun: snapshot.pulsesRun)
                #expect(tapper.tap(centre) == [.showPulse(pulse)])
                // A scrub from the left end to the right end sends each changed pulse under the finger, nothing else.
                var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, orbit: orbit)
                var actions: [Action] = script.event(1, .began, along[0], dt: 1)
                var expected: [Action] = []
                var last: Int? = nil
                for index in 1..<along.count {
                    let p: Vec2 = along[index]
                    actions += script.event(1, .moved, p)
                    guard (p - along[0]).length >= Controller.dragDistance else { continue }
                    let c: Vec2 = try #require(MyceliumArchitectPicker.cast(p, viewSize: Self.phone, orbit: orbit))
                    let value: Int = MyceliumArchitectPicker.pulse(atPlaneX: c.x, pulsesRun: snapshot.pulsesRun)
                    if value != last {
                        expected.append(.showPulse(value))
                        last = value
                    }
                }
                #expect(script.controller.state == .scrub)
                actions += script.event(1, .ended, along[along.count - 1])
                #expect(actions == expected)
                #expect(expected.count >= 2 || snapshot.pulsesRun < 2)
                var shown: Core = core
                for action in actions {
                    guard case .showPulse(let value) = action else { continue }
                    let result: ActionResult = shown.apply(ExperienceAction(control: "growth.show",
                                                                            values: [Double(value)], step: 0))
                    #expect(result.isAccepted)
                    #expect(shown.shownPulse == value)
                }
                #expect(try Self.digest(shown) == Self.digest(core))
            }
        }
    }

    // MARK: Second fingers, cancels, outside playing (FR-008, 009; SC-002)

    @Test func secondFingerCancelsAndOrbits() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map))
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var actions: [Action] = script.event(1, .began, site.point, dt: 1)
        let second: Vec2 = Vec2(site.point.x + 80, site.point.y)
        let cancel: [Action] = script.event(2, .began, second)
        #expect(cancel == [.clearPreview])
        #expect(script.controller.state == .orbiting)
        // Both fingers right by a tenth of the width and up by a twentieth of the height.
        let turn: [Action] = script.event(1, .moved, Vec2(site.point.x + 39, site.point.y))
            + script.event(2, .moved, Vec2(second.x + 39, second.y))
        #expect(turn.count == 2)
        #expect(abs(script.orbit.yaw - 0.1 * Double.pi / 2) < 1e-9)
        #expect(script.orbit.pitch == 0)
        let lift: [Action] = script.event(1, .moved, Vec2(site.point.x + 39, site.point.y - 42.2))
            + script.event(2, .moved, Vec2(second.x + 39, second.y - 42.2))
        #expect(lift.count == 2)
        #expect(abs(script.orbit.pitch - 0.05 * Double.pi / 3) < 1e-9)
        actions = script.event(1, .ended, site.point) + script.event(2, .ended, second)
        #expect(actions.isEmpty)
        #expect(script.controller.state == .idle)
        // The orbit stays within bounds however far the fingers go.
        var far: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        _ = far.event(1, .began, Vec2(100, 100), dt: 1)
        _ = far.event(2, .began, Vec2(200, 100))
        let wild: [Action] = far.event(1, .moved, Vec2(5000, -9000)) + far.event(2, .moved, Vec2(5100, -9000))
        for action in wild {
            guard case .orbit(let orbit) = action else { continue }
            #expect(orbit == orbit.clamped())
        }
    }

    @Test func cancelledTouchClearsThePreviewAndSendsNothing() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map))
        let root: Vec2 = try #require(map[.root])
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        var actions: [Action] = script.event(1, .began, site.point, dt: 1)
        actions += script.event(1, .cancelled, site.point)
        #expect(actions == [.preview(.nutrient(site.cell)), .clearPreview])
        actions = script.event(1, .began, root, dt: 1)
        actions += script.event(1, .moved, Vec2(root.x + 60, root.y + 60))
        actions += script.event(1, .cancelled, Vec2(root.x + 60, root.y + 60))
        #expect(Self.sends(actions).isEmpty)
        #expect(actions.last == .clearPreview)
        #expect(script.controller.state == .idle)
        _ = script.event(1, .began, site.point, dt: 1)
        script.controller.cancel()
        #expect(script.controller.state == .idle)
        #expect(script.event(1, .ended, site.point).isEmpty)
    }

    @Test func gesturesOutsidePlayingSendNoKernelAction() throws {
        let opening: Core = try Self.core(22)
        let failed: Core = Self.accepted(opening, "growth.run")
        #expect(failed.play.stage != .playing)
        let base: MyceliumArchitectSceneSnapshot = opening.snapshot(time: 0)
        let paused: MyceliumArchitectSceneSnapshot =
            MyceliumArchitectSceneSnapshot(level: base.level, arrangement: base.arrangement,
                                           report: opening.play.report, failure: nil, stage: .paused,
                                           actionsLeft: base.actionsLeft, shownPulse: base.shownPulse,
                                           levelNumber: base.levelNumber, time: 0)
        let cases: [MyceliumArchitectSceneSnapshot] = [failed.snapshot(time: 0), paused]
        var random: GestureRandom = GestureRandom(state: Self.seed)
        for snapshot in cases {
            let reason: String = Controller.stageReason(snapshot.stage)
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
            let site: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map))
            let root: Vec2 = try #require(map[.root])
            var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
            #expect(script.tap(site.point) == [.inspect(site.cell), .explain(reason)])
            let drag: [Action] = script.drag(root, Vec2(root.x + 80, root.y))
            #expect(drag == [.explain(reason)])
            // 100 seeded gestures from every target: never a kernel action.
            var targets: [Vec2] = []
            for (_, p) in map { targets.append(p) }
            targets.sort { a, b in a.y == b.y ? a.x < b.x : a.y < b.y }
            for _ in 0..<100 {
                let from: Vec2 = targets[random.below(targets.count)]
                let to: Vec2 = targets[random.below(targets.count)]
                let kind: Int = random.below(3)
                var actions: [Action] = []
                if kind == 0 {
                    actions = script.tap(from)
                } else if kind == 1 {
                    actions = script.drag(from, to)
                } else {
                    actions = script.event(1, .began, from, dt: 1) + script.event(2, .began, to)
                        + script.event(2, .moved, Vec2(to.x + 30, to.y)) + script.event(1, .ended, from)
                        + script.event(2, .ended, to)
                }
                #expect(Self.sends(actions).isEmpty)
                #expect(Self.previews(actions).isEmpty)
            }
        }
    }

    // MARK: View (FR-008)

    @Test func doubleTapOnEmptySpaceResetsTheView() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        let empty: Vec2 = Vec2(8, 8)
        let corner: Target = MyceliumArchitectPicker.pick(Vec2(13, 8), viewSize: Self.phone, snapshot: snapshot,
                                                          orbit: MyceliumArchitectViewOrbit(yaw: 0.3, pitch: 0.1))
        #expect(corner == .empty)
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone,
                                                  orbit: MyceliumArchitectViewOrbit(yaw: 0.3, pitch: 0.1))
        var actions: [Action] = script.event(1, .began, empty, dt: 1) + script.event(1, .ended, empty, dt: 0.05)
        #expect(actions.isEmpty)
        actions = script.event(1, .began, Vec2(empty.x + 5, empty.y), dt: 0.1)
            + script.event(1, .ended, Vec2(empty.x + 5, empty.y), dt: 0.05)
        #expect(actions == [.resetView])
        // A completed double tap starts no new one; a slow second tap does nothing.
        actions = script.event(1, .began, empty, dt: 0.05) + script.event(1, .ended, empty, dt: 0.05)
        #expect(actions.isEmpty)
        actions = script.event(1, .began, empty, dt: 0.4) + script.event(1, .ended, empty, dt: 0.05)
        #expect(actions.isEmpty)
    }

    @Test func unusableInputIsEmptySpace() throws {
        let snapshot: MyceliumArchitectSceneSnapshot = try Self.core(1).snapshot(time: 0)
        let sizes: [Vec2] = [Vec2(0, 0), Vec2(Double.nan, 800), Vec2(390, Double.infinity), Vec2(-10, 50)]
        for size in sizes {
            var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: size)
            #expect(script.tap(Vec2(100, 100)).isEmpty)
            #expect(script.drag(Vec2(100, 100), Vec2(300, 400)).isEmpty)
        }
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone)
        #expect(script.tap(Vec2(Double.nan, 10)).isEmpty)
        #expect(script.tap(Vec2(10, Double.infinity)).isEmpty)
    }

    // MARK: Previews (FR-006; SC-006) and refusals (FR-001)

    @Test func twoHundredSeededPreviewsEqualTheKernel() throws {
        var random: GestureRandom = GestureRandom(state: Self.seed)
        let numbers: [Int] = [1, 2, 21, 22, 64, 92]
        var previewsChecked: Int = 0
        var refusals: Int = 0
        var round: Int = 0
        while previewsChecked < 200 && round < 60 {
            let number: Int = numbers[round % numbers.count]
            round += 1
            var core: Core = try Self.core(number)
            // A random reachable arrangement: up to the whole budget of random actions (refused ones change nothing).
            let tries: Int = random.below(core.play.level.budget + 3)
            for _ in 0..<tries {
                let moves: [MyceliumArchitectAction] = MyceliumArchitectPuzzle(level: core.play.level)
                    .moves(in: MyceliumArchitectPuzzle.Position(arrangement: core.play.arrangement,
                                                                actionsSpent: core.play.actionsSpent))
                guard !moves.isEmpty, let send = Controller.send(moves[random.below(moves.count)]),
                      case .send(let control, let values) = send else { break }
                core = Self.accepted(core, control, values)
            }
            let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
            let orbit: MyceliumArchitectViewOrbit = Self.orbits[round % Self.orbits.count]
            let view: Vec2 = Self.phone
            let map: [Target: Vec2] = Self.points(snapshot, viewSize: view, orbit: orbit, step: 5)
            var candidates: [Target] = []
            for cell in snapshot.level.sites ?? [] where map[.cell(cell)] != nil { candidates.append(.cell(cell)) }
            for direction in snapshot.arrangement.seeds where map[.sprout(direction)] != nil {
                candidates.append(.sprout(direction))
            }
            if map[.root] != nil { candidates.append(.root) }
            for _ in 0..<12 {
                guard !candidates.isEmpty, let rootPoint = map[.root] else { break }
                let target: Target = candidates[random.below(candidates.count)]
                let tool: MyceliumArchitectTool = random.below(2) == 0 ? .nutrient : .blocker
                var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: view, tool: tool, orbit: orbit)
                var actions: [Action] = []
                var expected: MyceliumArchitectAction? = nil
                switch target {
                case .cell(let cell):
                    actions = script.tap(try #require(map[target]))
                    expected = Self.expectedChange(cell, snapshot, tool)
                case .sprout(let direction):
                    let p: Vec2 = try #require(map[target])
                    actions = script.event(1, .began, p, dt: 1) + script.event(1, .moved, Vec2(p.x + 25, p.y - 25))
                        + script.event(1, .moved, rootPoint) + script.event(1, .ended, rootPoint)
                    expected = .unseed(direction)
                default:
                    var ends: [Vec2] = []
                    for cell in snapshot.level.sites ?? [] {
                        if let p = map[.cell(cell)], (p - rootPoint).length >= 40 { ends.append(p) }
                    }
                    guard !ends.isEmpty else { continue }
                    let end: Vec2 = ends[random.below(ends.count)]
                    actions = script.drag(rootPoint, end)
                    let a: Vec2 = try #require(MyceliumArchitectPicker.cast(rootPoint, viewSize: view, orbit: orbit))
                    let b: Vec2 = try #require(MyceliumArchitectPicker.cast(end, viewSize: view, orbit: orbit))
                    expected = .seed(MyceliumArchitectPicker.direction(from: a, to: b))
                }
                let shown: [MyceliumArchitectAction] = Self.previews(actions)
                guard let change = expected else {
                    #expect(shown.isEmpty && Self.sends(actions).isEmpty)
                    continue
                }
                #expect(shown.last == change, "level \(number) \(target)")
                let sent: [(control: String, values: [Double])] = Self.sends(actions)
                #expect(sent.count == 1, "level \(number) \(target)")
                guard sent.count == 1, Controller.send(change) == .send(sent[0].control, sent[0].values) else {
                    Issue.record("level \(number) \(target): sent \(sent)")
                    continue
                }
                let previewed: Result<MyceliumArchitectReport, MyceliumArchitectError> = core.previewReport(change)
                let kernel: Result<MyceliumArchitectReport, MyceliumArchitectError> = Self.kernelPreview(core, change)
                #expect(previewed == kernel, "level \(number) \(change)")
                // The change sent once: accepted with exactly the previewed report, or refused with its reason code.
                var applied: Core = core
                let result: ActionResult = applied.apply(ExperienceAction(control: sent[0].control,
                                                                          values: sent[0].values, step: 0))
                switch kernel {
                case .success(let report):
                    #expect(result.isAccepted && applied.play.report == report, "level \(number) \(change)")
                case .failure(let error):
                    #expect(!result.isAccepted && result.code == "action.rule." + error.reasonCode, "level \(number) \(change)")
                    #expect(try Self.digest(applied) == Self.digest(core))
                    refusals += 1
                }
                previewsChecked += 1
            }
        }
        #expect(previewsChecked >= 200)
        #expect(refusals >= 1)
    }

    @Test func refusedPlacementIsSentOnceAndItsRefusalShown() throws {
        let opening: Core = try Self.core(1)
        let first: MyceliumArchitectSceneSnapshot = opening.snapshot(time: 0)
        #expect(first.level.maxNutrients == 1)
        let map0: [Target: Vec2] = Self.points(first, viewSize: Self.phone, orbit: .authored)
        let a: (cell: Cell, point: Vec2) = try #require(Self.emptySite(first, map0))
        let core: Core = Self.accepted(opening, "cell.nutrient", Self.values(a.cell))
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        let map: [Target: Vec2] = Self.points(snapshot, viewSize: Self.phone, orbit: .authored)
        let b: (cell: Cell, point: Vec2) = try #require(Self.emptySite(snapshot, map, skipping: [a.cell]))
        var script: GestureScript = GestureScript(snapshot: snapshot, viewSize: Self.phone, tool: .nutrient)
        let actions: [Action] = script.tap(b.point)
        #expect(actions == [.preview(.nutrient(b.cell)), .send("cell.nutrient", Self.values(b.cell)), .clearPreview])
        #expect(core.previewReport(.nutrient(b.cell)) == .failure(.action("nutrient limit")))
        var refused: Core = core
        let result: ActionResult = refused.apply(ExperienceAction(control: "cell.nutrient", values: Self.values(b.cell),
                                                                  step: 0))
        #expect(!result.isAccepted && result.code == "action.rule." + MyceliumArchitectError.action("nutrient limit").reasonCode)
        #expect(try Self.digest(refused) == Self.digest(core))
    }
}

