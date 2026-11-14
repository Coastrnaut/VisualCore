// ExperienceActionTests — feature 188 T-U02-008 (FR-U02-030, FR-U02-031, FR-U02-034, FR-U02-035): controls keep at
// most eight ranges, an action is checked in the order the contract states, a position is normalized only inside a
// view with area, and actions survive a JSON round trip.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ExperienceActionTests {
    private static let controls: [ExperienceControl] = [
        ExperienceControl(id: "fire"),
        ExperienceControl(id: "move", ranges: [0...1, 0...1]),
        ExperienceControl(id: "tune", ranges: [-10...10, 0...100, 5...5]),
        ExperienceControl(id: "move", ranges: [0...1]),
    ]

    @Test func controlDropsRangesBeyondTwentyFour() {
        // 24 since feature 043 (A05-P04 T-A05-416): one action restores a whole saved document.
        #expect(ExperienceControl.maxValues == 24)
        let thirty = (0..<30).map { Double($0)...Double($0 + 1) }
        let control = ExperienceControl(id: "wide", ranges: thirty)
        #expect(control.id == "wide")
        #expect(control.ranges.count == 24)
        #expect(control.ranges == Array(thirty.prefix(24)))
        #expect(ExperienceControl(id: "exact", ranges: Array(thirty.prefix(24))).ranges.count == 24)
        #expect(ExperienceControl(id: "none").ranges.isEmpty)
        #expect(ExperienceControl(id: "a", ranges: [0...1]) == ExperienceControl(id: "a", ranges: [0...1]))
        #expect(ExperienceControl(id: "a", ranges: [0...1]) != ExperienceControl(id: "a", ranges: [0...2]))
    }

    @Test func validationTable() {
        let nan = Double.nan
        let inf = Double.infinity
        let table: [(String, [Double], ActionRejection?)] = [
            // Well formed: a control without values, values inside and on both ends of their ranges.
            ("fire", [], nil),
            ("move", [0.25, 0.75], nil),
            ("move", [0, 0], nil),
            ("move", [1, 1], nil),
            ("tune", [-10, 100, 5], nil),
            ("tune", [10, 0, 5], nil),
            // Unknown control, also when the values are bad as well.
            ("jump", [], .unknownControl("jump")),
            ("", [nan], .unknownControl("")),
            ("Fire", [], .unknownControl("Fire")),
            // Wrong value count, also when a value is not finite or out of range.
            ("fire", [0.5], .wrongValueCount(expected: 0, found: 1)),
            ("move", [], .wrongValueCount(expected: 2, found: 0)),
            ("move", [0.5], .wrongValueCount(expected: 2, found: 1)),
            ("move", [nan, 7, 0.5], .wrongValueCount(expected: 2, found: 3)),
            // The first value that is not finite, before any range check.
            ("move", [nan, 0.5], .nonFinite(index: 0)),
            ("move", [0.5, inf], .nonFinite(index: 1)),
            ("move", [-inf, nan], .nonFinite(index: 0)),
            ("tune", [99, 50, nan], .nonFinite(index: 2)),
            // The first value out of range.
            ("move", [1.5, 0.5], .outOfRange(index: 0)),
            ("move", [0.5, -0.001], .outOfRange(index: 1)),
            ("move", [2, 2], .outOfRange(index: 0)),
            ("tune", [0, 100.5, 6], .outOfRange(index: 1)),
            ("tune", [0, 50, 5.000001], .outOfRange(index: 2)),
        ]
        #expect(table.count >= 12)
        for (control, values, expected) in table {
            let found = ExperienceInput.validate(control: control, values: values, controls: Self.controls)
            #expect(found == expected, "\(control) \(values)")
        }
    }

    @Test func validationUsesTheFirstControlOfADuplicatedId() {
        // "move" is declared twice; the first declaration (two values) counts.
        #expect(ExperienceInput.validate(control: "move", values: [0.5, 0.5], controls: Self.controls) == nil)
        #expect(ExperienceInput.validate(control: "move", values: [0.5], controls: Self.controls)
            == .wrongValueCount(expected: 2, found: 1))
    }

    @Test func validationWithoutDeclaredControls() {
        #expect(ExperienceInput.validate(control: "fire", values: [], controls: []) == .unknownControl("fire"))
    }

    @Test func validationCountsAgainstTheKeptRanges() {
        let wide = ExperienceControl(id: "wide", ranges: Array(repeating: 0...1, count: 26))
        let kept = Array(repeating: 0.5, count: ExperienceControl.maxValues)
        #expect(ExperienceInput.validate(control: "wide", values: kept, controls: [wide]) == nil)
        #expect(ExperienceInput.validate(control: "wide", values: kept + [0.5, 0.5], controls: [wide])
            == .wrongValueCount(expected: 24, found: 26))
    }

    @Test func normalizedMapsCornersAndCentre() {
        let table: [(Double, Double, Double, Double)] = [
            (0, 0, 0, 0),
            (200, 0, 1, 0),
            (0, 100, 0, 1),
            (200, 100, 1, 1),
            (100, 50, 0.5, 0.5),
            (50, 75, 0.25, 0.75),
        ]
        for (x, y, expectedX, expectedY) in table {
            let point = ExperienceInput.normalized(x: x, y: y, width: 200, height: 100)
            #expect(point != nil, "\(x) \(y)")
            #expect(point?.x == expectedX, "\(x) \(y)")
            #expect(point?.y == expectedY, "\(x) \(y)")
        }
    }

    @Test func normalizedIsNilOutsideTheView() {
        let outside: [(Double, Double)] = [(-0.001, 50), (200.001, 50), (100, -0.001), (100, 100.001), (-1, -1), (300, 300)]
        for (x, y) in outside {
            #expect(ExperienceInput.normalized(x: x, y: y, width: 200, height: 100) == nil, "\(x) \(y)")
        }
    }

    @Test func normalizedIsNilForAViewWithoutArea() {
        let sizes: [(Double, Double)] = [(0, 100), (200, 0), (0, 0), (-200, 100), (200, -100), (-200, -100)]
        for (width, height) in sizes {
            #expect(ExperienceInput.normalized(x: 0, y: 0, width: width, height: height) == nil, "\(width) \(height)")
        }
    }

    @Test func normalizedIsNilForValuesThatAreNotFinite() {
        let nan = Double.nan
        let inf = Double.infinity
        let table: [(Double, Double, Double, Double)] = [
            (nan, 50, 200, 100), (100, nan, 200, 100), (100, 50, nan, 100), (100, 50, 200, nan),
            (inf, 50, 200, 100), (100, -inf, 200, 100), (100, 50, inf, 100), (100, 50, 200, inf),
            (inf, inf, inf, inf),
        ]
        for (x, y, width, height) in table {
            #expect(ExperienceInput.normalized(x: x, y: y, width: width, height: height) == nil)
        }
    }

    @Test func experienceActionSurvivesAJSONRoundTrip() throws {
        let actions = [
            ExperienceAction(control: "fire", step: 0),
            ExperienceAction(control: "move", values: [0.25, 0.75], step: 42),
            ExperienceAction(control: "tune", values: [-10, 100, 5, 0.1, 1e-9, 123_456.789], step: Int.max),
        ]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            #expect(try JSONDecoder().decode(ExperienceAction.self, from: data) == action)
        }
        let whole = try JSONDecoder().decode([ExperienceAction].self, from: try JSONEncoder().encode(actions))
        #expect(whole == actions)

        let text = Data(#"{"control":"move","values":[0.5,1],"step":7}"#.utf8)
        let decoded = try JSONDecoder().decode(ExperienceAction.self, from: text)
        #expect(decoded == ExperienceAction(control: "move", values: [0.5, 1], step: 7))
        #expect(ExperienceAction(control: "fire", step: 3).values.isEmpty)
        #expect(ExperienceAction(control: "fire", step: 3) != ExperienceAction(control: "fire", step: 4))
    }

    @Test func scriptedActionSurvivesAJSONRoundTrip() throws {
        let actions = [ScriptedAction("fire"), ScriptedAction("move", [0.25, 0.75]), ScriptedAction("tune", [-10, 100, 5])]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            #expect(try JSONDecoder().decode(ScriptedAction.self, from: data) == action)
        }
        let text = Data(#"{"control":"move","values":[0,1]}"#.utf8)
        #expect(try JSONDecoder().decode(ScriptedAction.self, from: text) == ScriptedAction("move", [0, 1]))
        #expect(ScriptedAction("fire").values.isEmpty)
        #expect(ScriptedAction("fire").control == "fire")
    }

    @Test func nonFiniteValuesAreRefusedByTheJSONEncoder() {
        #expect(throws: (any Error).self) {
            try JSONEncoder().encode(ExperienceAction(control: "move", values: [.nan, 0], step: 1))
        }
        #expect(throws: (any Error).self) {
            try JSONEncoder().encode(ScriptedAction("move", [.infinity]))
        }
    }
}
