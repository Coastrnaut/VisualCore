// InstanceOrderTests — feature 209 (R02-F09) T-R02F09-002 (FR-R02F09-003; SC-R02F09-003). Scrambled depths come back
// farthest first, equal depths keep their submission order, an empty list is empty and a non-finite depth is refused.
import Testing
@testable import VisualCoreScenes

@Suite struct InstanceOrderTests {
    @Test func scrambledDepthsComeBackFarthestFirst() throws {
        let depths: [Double] = [-3, -10, -1, -7, -5]
        #expect(try InstanceOrder.backToFront(depths: depths) == [1, 3, 4, 0, 2])
        for order in [[4, 0, 2, 3, 1], [2, 3, 1, 4, 0], [0, 1, 2, 3, 4]] {
            let scrambled = order.map { depths[$0] }
            let sorted = try InstanceOrder.backToFront(depths: scrambled).map { scrambled[$0] }
            #expect(sorted == [-10, -7, -5, -3, -1])
        }
    }

    @Test func equalDepthsKeepSubmissionOrder() throws {
        #expect(try InstanceOrder.backToFront(depths: [-2, -5, -2, -5, -2]) == [1, 3, 0, 2, 4])
    }

    @Test func emptyAndNonFinite() throws {
        #expect(try InstanceOrder.backToFront(depths: []) == [])
        #expect(throws: MeshError.invalidInput("depth 1 is not finite")) {
            _ = try InstanceOrder.backToFront(depths: [-1, .nan, -2])
        }
        #expect(throws: MeshError.self) { _ = try InstanceOrder.backToFront(depths: [.infinity]) }
    }
}
