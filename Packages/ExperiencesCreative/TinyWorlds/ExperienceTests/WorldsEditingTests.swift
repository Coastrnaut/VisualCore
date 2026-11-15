// WorldsEditingTests — feature 091 (A12-P03) T-A12-303 (FR-A12-302, FR-A12-303, FR-A12-310, FR-A12-320; SC-A12-301,
// SC-A12-305; clarifications Q2–Q4; contracts/actions.md; acceptance scenarios US1-1 … US1-3, US2-1). The editing and
// light actions of Tiny Worlds through the engine and the shell, short runs only (each test well under 10 s):
//   - every prop action follows the editor's rules through the engine: a placed prop rests on the drawn terrain and is
//     selected, the refusals carry their codes (`a12.outside`, `a12.under-water`, `a12.too-close`, `a12.no-selection`,
//     `a12.invalid-choice`) or the engine's range refusals, and a refusal changes nothing; replaying the same actions
//     gives the same state and digest; a preset change clears the props;
//   - the 25th prop is refused with `a12.prop-cap`;
//   - the light actions set the light (and are refused outside their ranges);
//   - a tap selects a prop when its picking box is nearer than the ground (through `prop.select`), and otherwise picks
//     the ground point Place then uses;
//   - the stored schema-1 example migrates through the step 1 → 2 (no props, no selection, the default light) and
//     passes the registry's migration check; the step refuses a payload that is not schema 1;
//   - every action has a native control (`GestureAlternatives.missing` is empty) and the new controls' identifiers;
//   - editing actions sent by the controls are answered in words (refusals and confirmations), spoken while
//     VoiceOver runs, and the description names the props.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreUI

@MainActor
final class WorldsEditingTests: XCTestCase {
    private let worldsID = ExperienceID(rawValue: WorldsCore.experienceID)!

    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<WorldsCore> {
        var engine = ExperienceEngine<WorldsCore>(id: worldsID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func rule(_ refusal: WorldEditRefusal) -> ActionResult { .rejected(.rule(code: refusal.rawValue)) }

    func testPropActionsThroughTheEngineFollowTheRules() async throws {
        var engine = try await makeEngine()
        let field = try XCTUnwrap(WorldEditing.groundField(of: WorldState.initial))
        XCTAssertEqual(engine.handle(control: "prop.place", values: [0, 0, 0]), .accepted)
        var core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.props.count, 1)
        XCTAssertEqual(core.props[0].kind, .tree)
        XCTAssertEqual(core.props[0].y, WorldEditing.groundHeight(field: field, x: 0, z: 0), accuracy: 1e-3,
                       "rests on the drawn terrain")
        XCTAssertEqual(core.selection, 0, "the placed prop is selected")
        let digest = try engine.digest()
        let refusals: [(String, [Double], ActionResult)] = [
            ("prop.place", [1, 0.3, 0], rule(.tooClose)),
            ("prop.place", [1, 5.8, 0], rule(.outside)),
            ("prop.place", [1, 5.4, 5.4], rule(.underWater)),
            ("prop.place", [1.5, 1, 1], rule(.invalidChoice)),
            ("prop.place", [4, 1, 1], .rejected(.outOfRange(index: 0))),
            ("prop.place", [0, 7, 0], .rejected(.outOfRange(index: 1))),
            ("prop.place", [0, 1, .nan], .rejected(.nonFinite(index: 2))),
            ("prop.place", [0, 1], .rejected(.wrongValueCount(expected: 3, found: 2))),
            ("prop.select", [5], rule(.invalidChoice)),
            ("prop.select", [0.5], rule(.invalidChoice)),
            ("prop.select", [24], .rejected(.outOfRange(index: 0))),
            ("prop.move", [1.5, 0], .rejected(.outOfRange(index: 0)))
        ]
        for (control, values, expected) in refusals {
            XCTAssertEqual(engine.handle(control: control, values: values), expected, "\(control) \(values)")
        }
        XCTAssertEqual(try engine.digest(), digest, "every refusal changes nothing")

        XCTAssertEqual(engine.handle(control: "prop.select", values: [-1]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).selection, -1)
        XCTAssertEqual(engine.handle(control: "prop.move", values: [0.5, 0]), rule(.noSelection))
        XCTAssertEqual(engine.handle(control: "prop.rotate", values: [45]), rule(.noSelection))
        XCTAssertEqual(engine.handle(control: "prop.delete"), rule(.noSelection))
        XCTAssertEqual(engine.handle(control: "prop.select", values: [0]), .accepted)
        XCTAssertEqual(engine.handle(control: "prop.move", values: [0.5, -0.25]), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.props[0].x, 0.5)
        XCTAssertEqual(core.props[0].z, -0.25)
        XCTAssertEqual(core.props[0].y, WorldEditing.groundHeight(field: field, x: 0.5, z: -0.25), "snapped again")
        XCTAssertEqual(engine.handle(control: "prop.move", values: [0, 6]), .rejected(.outOfRange(index: 1)))
        XCTAssertEqual(engine.handle(control: "prop.rotate", values: [45]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).props[0].rotation, Double.pi / 4, accuracy: 1e-15)
        XCTAssertEqual(engine.handle(control: "prop.rotate", values: [200]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "prop.place", values: [2, 1.5, 0.5]), .accepted)
        XCTAssertEqual(engine.handle(control: "prop.delete"), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.props.map(\.kind), [.tree])
        XCTAssertEqual(core.selection, -1, "the deleted prop's selection clears")

        // Replaying the same actions gives the same state and digest.
        var again = try await makeEngine()
        let replay: [(String, [Double])] = [
            ("prop.place", [0, 0, 0]), ("prop.select", [-1]), ("prop.select", [0]), ("prop.move", [0.5, -0.25]),
            ("prop.rotate", [45]), ("prop.place", [2, 1.5, 0.5]), ("prop.delete", []),
        ]
        for (control, values) in replay {
            XCTAssertEqual(again.handle(control: control, values: values), .accepted, control)
        }
        XCTAssertEqual(try XCTUnwrap(again.core).state, core.state)
        XCTAssertEqual(try again.digest(), try engine.digest())

        // A preset change clears the props and the selection; the light stays.
        XCTAssertEqual(engine.handle(control: "light.elevation", values: [20]), .accepted)
        XCTAssertEqual(engine.handle(control: "world.preset", values: [1]), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertTrue(core.props.isEmpty)
        XCTAssertEqual(core.selection, -1)
        XCTAssertEqual(core.light.elevation, 20)
        XCTAssertEqual(engine.handle(control: "prop.place", values: [0, 5.5, 5.5]), rule(.underWater),
                       "off the asteroid's disc")
    }

    func testTheTwentyFifthPropIsRefused() throws {
        let full = worldsStateWithProps(count: WorldEditing.maxProps)
        XCTAssertEqual(full.props.count, 24)
        var core = try worldsCore(full)
        let before = core
        XCTAssertEqual(core.apply(ExperienceAction(control: "prop.place", values: [0, 5, -5], step: 0)),
                       rule(.propCap))
        XCTAssertEqual(core, before)
        XCTAssertEqual(WorldsCore.selectRange, -1...23)
    }

    func testTheLightActionsSetTheLight() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(try XCTUnwrap(engine.core).light, .default)
        XCTAssertEqual(engine.handle(control: "light.azimuth", values: [120]), .accepted)
        XCTAssertEqual(engine.handle(control: "light.elevation", values: [30]), .accepted)
        XCTAssertEqual(engine.handle(control: "light.ambient", values: [0.2]), .accepted)
        let light = try XCTUnwrap(engine.core).light
        XCTAssertEqual(light, WorldLight(azimuth: 120, elevation: 30, ambient: 0.2))
        XCTAssertEqual(light.direction.length, 1, accuracy: 1e-12)
        XCTAssertEqual(engine.handle(control: "light.azimuth", values: [360]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).light.azimuth, 0, "360 wraps to 0")
        let digest = try engine.digest()
        XCTAssertEqual(engine.handle(control: "light.azimuth", values: [361]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "light.elevation", values: [5]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "light.elevation", values: [86]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "light.ambient", values: [0.7]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "light.ambient", values: []),
                       .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(try engine.digest(), digest)

        // Called directly, the core refuses out-of-range values with its own rule.
        var core = try XCTUnwrap(engine.core)
        let original = core
        let outside: [(String, Double)] = [("light.azimuth", -10), ("light.elevation", 90), ("light.ambient", 0.05),
                                           ("light.ambient", .nan)]
        for (control, value) in outside {
            XCTAssertEqual(core.apply(ExperienceAction(control: control, values: [value], step: 0)),
                           rule(.invalidChoice), control)
        }
        XCTAssertEqual(core, original)
    }

    func testATapSelectsAPropNearerThanTheGround() async throws {
        // The pure decision: a ray straight down onto a prop meets its box before the ground.
        let state = worldsStateWithProps(count: 1)
        let prop = state.props[0]
        let field = WorldEditing.groundField(of: state)
        let down = try XCTUnwrap(Ray3(origin: Vec3(prop.x, 5, prop.z), direction: Vec3(0, -1, 0)))
        let onProp = WorldsPresenter.tapTarget(ray: down, props: state.props, field: field)
        XCTAssertEqual(onProp.prop, 0)
        let beside = try XCTUnwrap(Ray3(origin: Vec3(prop.x + 2, 5, prop.z + 2), direction: Vec3(0, -1, 0)))
        let ground = WorldsPresenter.tapTarget(ray: beside, props: state.props, field: field)
        XCTAssertNil(ground.prop)
        XCTAssertNotNil(ground.ground)

        // Through the shell: tap the house's middle on the canvas.
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: CGSize(width: 240, height: 200), announcements: sink)
        XCTAssertTrue(shell.handle(control: "view.zoom", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "prop.place", values: [2, 0, 0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "prop.select", values: [-1]).isAccepted)
        try WorldsTest.settle(session, shell)
        let core = try WorldsTest.core(shell)
        let house = core.props[0]
        let size = Vec2(240, 200)
        let view = try XCTUnwrap(shell.presenter.lastDrawnView)
        let point = try XCTUnwrap(WorldsTest.viewPoint(Vec3(house.x, house.y + 0.3, house.z), view: view, size: size))
        shell.handlePointer(PointerEvent(id: 1, phase: .began, location: point, timestamp: 0), viewSize: size)
        shell.handlePointer(PointerEvent(id: 1, phase: .ended, location: point, timestamp: 0.05), viewSize: size)
        XCTAssertEqual(try WorldsTest.core(shell).selection, 0, "the tap selects the house")
        XCTAssertEqual(shell.presenter.lastPick, "Selected the house, prop 1 of 1.")
        XCTAssertEqual(sink.announced.last, "Selected the house, prop 1 of 1.")

        // A tap on the ground away from the house picks the ground for the next Place.
        let groundPoint = try XCTUnwrap(WorldsTest.viewPoint(Vec3(-1.5, house.y, 1.5), view: view, size: size))
        shell.handlePointer(PointerEvent(id: 2, phase: .began, location: groundPoint, timestamp: 1), viewSize: size)
        shell.handlePointer(PointerEvent(id: 2, phase: .ended, location: groundPoint, timestamp: 1.05), viewSize: size)
        let picked = try XCTUnwrap(shell.presenter.lastGround)
        XCTAssertTrue(shell.presenter.lastPick?.hasPrefix("Ground at x ") ?? false)
        XCTAssertEqual(try WorldsTest.core(shell).selection, 0, "a ground tap keeps the selection")
        XCTAssertEqual(shell.presenter.placeValues(kind: 1), [1, picked.x, picked.z])
        shell.presenter.send("prop.place", shell.presenter.placeValues(kind: 1)) {
            shell.handle(control: $0, values: $1)
        }
        let placed = try WorldsTest.core(shell)
        XCTAssertEqual(placed.props.count, 2)
        XCTAssertEqual(placed.props[1].x, picked.x)
        XCTAssertEqual(placed.props[1].z, picked.z)
        session.close()
    }

    func testTheSchemaOneExampleMigrates() async throws {
        let example = try XCTUnwrap(WorldsCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let problems = await SnapshotMigrationCheck.problems(for: WorldsCore.self, id: worldsID, examples: [example])
        XCTAssertEqual(problems, [])
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                    as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["presetIndex", "random", "schema", "seed", "view"], "as A12-P02 wrote it")
        XCTAssertEqual(payload["schema"] as? Int, 1)

        var engine = try await makeEngine(seed: 7)
        try engine.restore(snapshot)
        let core = try XCTUnwrap(engine.core)
        XCTAssertTrue(core.props.isEmpty)
        XCTAssertEqual(core.selection, -1)
        XCTAssertEqual(core.light, .default)
        XCTAssertEqual(core.preset, .asteroidGarden)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        XCTAssertEqual(WorldsCore.migrations.currentVersion, 2)

        // The step refuses a payload that is not schema 1.
        var two = payload
        two["schema"] = 2
        XCTAssertThrowsError(try WorldsCore.migratedToSchemaTwo(two)) { error in
            XCTAssertEqual(error as? WorldsRestoreError, .notSchemaOne(2))
        }
    }

    func testEveryActionHasANativeControl() {
        let presenter = WorldsPresenter(experienceID: WorldsTest.id)
        XCTAssertEqual(presenter.nativeActions, Set(WorldsCore.actionIDs))
        XCTAssertEqual(presenter.gestureActions, ["view.orbit", "view.zoom", "prop.select"])
        XCTAssertTrue(presenter.gestureActions.isSubset(of: Set(WorldsCore.actionIDs)))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
        XCTAssertEqual(WorldsControls.nextIndex(-1, count: 3), 0)
        XCTAssertEqual(WorldsControls.nextIndex(2, count: 3), 0)
        XCTAssertEqual(WorldsControls.previousIndex(-1, count: 3), 2)
        XCTAssertEqual(WorldsControls.previousIndex(0, count: 3), 2)
        XCTAssertEqual(WorldsControls.previousIndex(2, count: 3), 1)
        XCTAssertNil(WorldsControls.nextIndex(-1, count: 0))
        XCTAssertEqual(WorldsControls.azimuth(350, steps: 1), 5)
        XCTAssertEqual(WorldsControls.azimuth(0, steps: -1), 345)
        XCTAssertEqual(WorldsControls.stepped(0.35, by: 0.05, in: WorldLight.ambientRange), 0.4)
        XCTAssertEqual(WorldsControls.stepped(0.6, by: 0.05, in: WorldLight.ambientRange), 0.6)
        XCTAssertEqual(WorldsControls.stepped(85, by: 5, in: WorldLight.elevationRange), 85)
        let port = TinyWorldsExperience.make(id: WorldsTest.id).port
        for name in ["prop-kind", "place", "select-previous", "select-next", "move-west", "move-east", "move-south",
                     "move-north", "rotate-left", "rotate-right", "delete", "message", "light-azimuth",
                     "light-elevation", "light-ambient", "slot-0-save", "slot-3-open", "slot-2-clear",
                     "slot-1-status", "slot-0-picture"] {
            XCTAssertEqual(port.identifier(name), "experience.a12.tiny-worlds.\(name)")
        }
    }

    func testEditingActionsAreAnsweredInWords() async throws {
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, announcements: sink)
        let presenter = shell.presenter
        func send(_ control: String, _ values: [Double] = []) -> String {
            presenter.send(control, values) { shell.handle(control: $0, values: $1) }
            return presenter.mirror.message
        }
        XCTAssertEqual(send("prop.place", [0, 5.8, 0]), "Not done: that point is outside the world.")
        XCTAssertEqual(send("prop.place", [0, 5.4, 5.4]), "Not done: that point is under water.")
        XCTAssertEqual(send("prop.delete"), "Not done: no prop is selected.")
        XCTAssertEqual(send("prop.place", [0, 0, 0]), "Placed a tree at x 0.0, z 0.0.")
        XCTAssertEqual(send("prop.place", [3, 0.2, 0.2]), "Not done: too close to another prop.")
        XCTAssertEqual(send("prop.place", [1, 2, 3, 4]), "Not done: that value is out of range.")
        XCTAssertEqual(send("prop.move", [0.5, 0]), "Moved the tree to x 0.5, z 0.0.")
        XCTAssertEqual(send("prop.rotate", [-45]), "Turned the tree to -45 degrees.")
        XCTAssertEqual(send("prop.select", [-1]), "No prop selected.")
        XCTAssertEqual(send("prop.select", [0]), "Selected the tree, prop 1 of 1.")
        XCTAssertEqual(send("light.elevation", [30]), "Light from 30 degrees, 30 degrees up, ambient 0.35.")
        XCTAssertEqual(sink.announced.last, "Light from 30 degrees, 30 degrees up, ambient 0.35.")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("18 metres away; 1 prop, the tree selected."),
                      shell.accessibilitySummary)
        XCTAssertEqual(send("prop.delete"), "Deleted the tree.")
        XCTAssertEqual(send("prop.place", [2, 1, 1]), "Placed a house at x 1.0, z 1.0.")
        XCTAssertEqual(send("world.seed"), "The props were cleared for the new terrain.")
        XCTAssertEqual(WorldsPresenter.propsWords([], selection: -1), nil)
        let count = sink.announced.count
        XCTAssertEqual(send("view.orbit", [10, 0]), "The props were cleared for the new terrain.",
                       "view actions are spoken by the view announcer, not here")
        XCTAssertEqual(sink.announced.count, count)
        session.close()
    }
}
