// IsolateTests — feature 126 (A17-P03) T-A17-305 (FR-A17-304; SC-A17-304; clarification Q3). The isolate rules for
// every target (14 parts, 3 layers) and both modes: the solid set is the target set plus the selection, the selection
// is always solid, the ghosts are the other parts on shown layers in the ghost mode and none in the hide mode; an
// isolate shows its set even when its layer is hidden; without an isolate the A17-P02 rules hold; the JSON shape.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

@Suite struct IsolateTests {
    /// The 14 parts of the bundled knee in inventory order.
    private static func isolateParts() throws -> [AnatomicalStructure] {
        try AnatomyContent.bundledRightKnee().structures.filter { $0.parent != nil }
    }

    /// Every isolate target: each part, then each layer.
    private static func isolateTargets(_ parts: [AnatomicalStructure]) -> [AnatomyIsolate.Target] {
        parts.indices.map { AnatomyIsolate.Target.part($0) } + AnatomyLayer.allCases.map { .layer($0) }
    }

    @Test func everyTargetAndModeGivesTheRuleSets() throws {
        let parts = try Self.isolateParts()
        let layers: [[Bool]] = [[true, true, true], [true, false, true], [false, false, false]]
        for target in Self.isolateTargets(parts) {
            for mode in AnatomyIsolate.Mode.allCases {
                for shown in layers {
                    let isolate = AnatomyIsolate(target: target, mode: mode)
                    let targetSet = isolate.targetSet(parts: parts)
                    let selected = parts.indices.first { !targetSet.contains($0) } ?? 0
                    let state = AnatomyViewState(camera: .opening, visibleLayers: shown, selection: parts[selected].id,
                                                 framed: nil, isolate: isolate)
                    let solid = state.solidParts(parts: parts)
                    let ghosts = state.ghostParts(parts: parts)
                    #expect(solid == targetSet.union([selected]), "\(target) \(mode)")
                    #expect(solid.contains(selected), "\(target) \(mode): the selection is solid")
                    #expect(solid.isDisjoint(with: ghosts), "\(target) \(mode)")
                    let shownSet = state.visibleLayerSet
                    let others = Set(parts.indices.filter { !solid.contains($0) && shownSet.contains(parts[$0].layer ?? .bones) })
                    #expect(ghosts == (mode == .ghost ? others : []), "\(target) \(mode) \(shown)")
                }
            }
        }
    }

    @Test func anIsolateShowsItsSetOnAHiddenLayer() throws {
        let parts = try Self.isolateParts()
        let acl = try #require(parts.firstIndex { $0.id == "knee.acl" })
        let hidden = AnatomyViewState(camera: .opening, visibleLayers: [true, true, false], selection: nil, framed: nil,
                                      isolate: AnatomyIsolate(target: .part(acl)))
        #expect(hidden.solidParts(parts: parts) == [acl])
        #expect(hidden.ghostParts(parts: parts) == Set(0..<8))
        let layer = AnatomyViewState(camera: .opening, visibleLayers: [false, false, false], selection: nil,
                                     framed: nil, isolate: AnatomyIsolate(target: .layer(.ligaments), mode: .hide))
        #expect(layer.solidParts(parts: parts) == Set(8..<14))
        #expect(layer.ghostParts(parts: parts).isEmpty)
    }

    @Test func withoutAnIsolateTheLayerTogglesHold() throws {
        let parts = try Self.isolateParts()
        let state = AnatomyViewState(camera: .opening, visibleLayers: [true, false, true], selection: nil, framed: nil)
        #expect(state.solidParts(parts: parts) == Set(0..<4).union(8..<14))
        #expect(state.ghostParts(parts: parts).isEmpty)
        #expect(AnatomyViewState.opening.solidParts(parts: parts) == Set(0..<14))
        #expect(AnatomyIsolate(target: .layer(.bones)).mode == .ghost)
    }

    @Test func theJSONShapeIsKindIdAndMode() throws {
        let parts = try Self.isolateParts()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.userInfo[AnatomyIsolate.partIDsKey] = parts.map(\.id)
        let part = AnatomyIsolate(target: .part(9), mode: .hide)
        let partText = String(decoding: try encoder.encode(part), as: UTF8.self)
        #expect(partText == #"{"id":"knee.pcl","kind":"part","mode":"hide"}"#)
        let layer = AnatomyIsolate(target: .layer(.cartilage))
        let layerText = String(decoding: try encoder.encode(layer), as: UTF8.self)
        #expect(layerText == #"{"id":"cartilage","kind":"layer","mode":"ghost"}"#)
        let decoder = JSONDecoder()
        decoder.userInfo[AnatomyIsolate.partIDsKey] = parts.map(\.id)
        #expect(try decoder.decode(AnatomyIsolate.self, from: Data(partText.utf8)) == part)
        #expect(try decoder.decode(AnatomyIsolate.self, from: Data(layerText.utf8)) == layer)
        #expect(AnatomyIsolate.bundledPartIDs == parts.map(\.id))
        #expect(throws: (any Error).self) {
            try decoder.decode(AnatomyIsolate.self, from: Data(#"{"id":"knee.elbow","kind":"part","mode":"hide"}"#.utf8))
        }
    }
}
