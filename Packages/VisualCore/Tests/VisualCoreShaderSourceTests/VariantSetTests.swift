// VariantSetTests — feature 206 T-R02F06-004 (FR-R02F06-003, clarification Q3, research R4).
import Testing
@testable import VisualCoreShaderSource

@Test func twoByThreeGivesSixCombinationsInLexicographicOrder() throws {
    // Given out of order: switches are sorted by name, values keep their index order.
    let set = try ShaderVariantSet([
        VariantSwitch(name: "QUALITY", values: ["0", "1", "2"]),
        VariantSwitch(name: "BLOOM", values: ["0", "1"]),
    ])
    #expect(set.switches.map(\.name) == ["BLOOM", "QUALITY"])
    #expect(set.combinations.map(\.key) == [
        "BLOOM=0;QUALITY=0", "BLOOM=0;QUALITY=1", "BLOOM=0;QUALITY=2",
        "BLOOM=1;QUALITY=0", "BLOOM=1;QUALITY=1", "BLOOM=1;QUALITY=2",
    ])
    #expect(set.combinations[4].defines == (try DefineSet(["BLOOM": "1", "QUALITY": "1"])))
    #expect(Set(set.combinations.map(\.key)).count == 6)
}

@Test func valueIndexOrderIsNotSortedOrder() throws {
    let set = try ShaderVariantSet([VariantSwitch(name: "MODE", values: ["2", "10", "1"])])
    #expect(set.combinations.map(\.key) == ["MODE=2", "MODE=10", "MODE=1"])
}

@Test func moreThan64CombinationsAreRefused() throws {
    // 65 itself is 5 × 13 and cannot be built from switches of at most 8 values, so the bound is shown with the
    // nearest products above 64; exactly 64 is accepted.
    let eight = try VariantSwitch(name: "E", values: (0..<8).map(String.init))
    let eight2 = try VariantSwitch(name: "F", values: (0..<8).map(String.init))
    #expect(try ShaderVariantSet([eight, eight2]).combinations.count == 64)
    let two = try VariantSwitch(name: "G", values: ["0", "1"])
    #expect(throws: VariantError.tooManyCombinations(128)) { try ShaderVariantSet([eight, eight2, two]) }
    let five = try VariantSwitch(name: "A", values: (0..<5).map(String.init))
    let seven = try VariantSwitch(name: "B", values: (0..<7).map(String.init))
    #expect(throws: VariantError.tooManyCombinations(70)) { try ShaderVariantSet([five, seven, two]) }
}

@Test func duplicatesAndBoundsAreRefused() throws {
    #expect(throws: VariantError.duplicateValue("A", "1")) { try VariantSwitch(name: "A", values: ["1", "2", "1"]) }
    #expect(throws: VariantError.noValues("A")) { try VariantSwitch(name: "A", values: []) }
    #expect(throws: VariantError.tooManyValues("A")) { try VariantSwitch(name: "A", values: (0..<9).map(String.init)) }
    let a = try VariantSwitch(name: "A", values: ["0"])
    let a2 = try VariantSwitch(name: "A", values: ["1"])
    #expect(throws: VariantError.duplicateSwitch("A")) { try ShaderVariantSet([a, a2]) }
    let seven = try (0..<7).map { try VariantSwitch(name: "S\($0)", values: ["0"]) }
    #expect(throws: VariantError.tooManySwitches(7)) { try ShaderVariantSet(seven) }
    #expect(try ShaderVariantSet(Array(seven.prefix(6))).combinations.count == 1)
}

@Test func namesAndValuesAreValidatedAsDefines() {
    #expect(throws: VariantError.define(.reservedName("GL_X"))) { try VariantSwitch(name: "GL_X", values: ["1"]) }
    #expect(throws: VariantError.define(.invalidName("1A"))) { try VariantSwitch(name: "1A", values: ["1"]) }
    #expect(throws: VariantError.define(.invalidValue("A"))) { try VariantSwitch(name: "A", values: ["1\n2"]) }
}

@Test func singleCombination() throws {
    let set = try ShaderVariantSet([VariantSwitch(name: "HQ", values: ["1"])])
    #expect(set.combinations.count == 1)
    #expect(set.combinations[0].key == "HQ=1")
    #expect(set.combinations[0].defines.lines == ["#define HQ 1"])
    let empty = try ShaderVariantSet([])
    #expect(empty.combinations.map(\.key) == [""])
    #expect(empty.combinations[0].defines == .empty)
}
