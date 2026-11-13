// GestureAlternativesTests — feature 226 (R02-F26) T-R02F26-005 (FR-R02F26-010; SC-R02F26-002).
import Testing
import VisualCoreExperience

@Suite struct GestureAlternativesTests {
    @Test func coveredGesturesLeaveNothingMissing() {
        #expect(GestureAlternatives.missing(gesture: ["zoom", "pan"], native: ["zoom", "pan", "reset"]).isEmpty)
        #expect(GestureAlternatives.missing(gesture: [], native: ["reset"]).isEmpty)
    }

    @Test func aGestureActionWithoutNativeControlIsNamedInOrder() {
        #expect(GestureAlternatives.missing(gesture: ["zoom", "rotate", "pan"], native: ["pan"]) == ["rotate", "zoom"])
    }
}
