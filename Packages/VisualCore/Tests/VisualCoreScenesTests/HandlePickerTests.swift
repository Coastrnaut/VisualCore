// HandlePickerTests — feature 222 (R02-F22) T-R02F22-003 (FR-R02F22-002; SC-R02F22-002; clarification Q2). 200 seeded
// handle sets around seeded orbit cameras pick what a brute-force reference of the rule picks (projection through
// `ScreenProjection.project`, selection written here independently); ties go by depth then index; handles behind the
// camera or outside the depth range are skipped; the touch radius is raised to 22 points; a non-finite touch picks
// nothing; refusals carry their reason codes; handles round-trip through JSON and a bad decoded handle is refused.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64); the scenes tests do not depend on VisualCoreSimulation.
fileprivate struct SplitMix64 {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform value in `range`.
    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(UInt64(1) << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    /// A uniform integer in `range`.
    mutating func integer(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }
}

/// One candidate of the reference rule.
fileprivate struct Candidate {
    let index: Int
    let distance: Double
    let depth: Double
}

/// The rule of clarification Q2, written independently of `HandlePicker`: collect every candidate, then take the
/// lexicographic minimum of (distance, depth, index).
fileprivate func referencePick(_ handles: [SpatialHandle], touch: Vec2, viewProjection: Mat4, viewport: Vec2,
                               touchRadius: Double) -> Int? {
    if !touch.isFinite { return nil }
    var radius: Double = 22
    if touchRadius.isFinite && touchRadius > 22 { radius = touchRadius }
    var candidates: [Candidate] = []
    var index = 0
    while index < handles.count {
        let handle = handles[index]
        if let projected = ScreenProjection.project(handle.position, viewProjection: viewProjection,
                                                    viewport: viewport),
           projected.depth >= -1, projected.depth <= 1 {
            let distance = (projected.point - touch).length
            let limit = handle.hitRadius > radius ? handle.hitRadius : radius
            if distance <= limit {
                candidates.append(Candidate(index: index, distance: distance, depth: projected.depth))
            }
        }
        index += 1
    }
    if candidates.isEmpty { return nil }
    var best = candidates[0]
    for candidate in candidates {
        if candidate.distance != best.distance {
            if candidate.distance < best.distance { best = candidate }
        } else if candidate.depth != best.depth {
            if candidate.depth < best.depth { best = candidate }
        } else if candidate.index < best.index {
            best = candidate
        }
    }
    return best.index
}

/// The default test camera: eye at (0, 0, 5) looking at the origin along −z.
fileprivate let frontCamera = OrbitCamera()
fileprivate let squareViewport = Vec2(400, 400)
fileprivate let center = Vec2(200, 200)

fileprivate func frontViewProjection() -> Mat4 { frontCamera.viewProjection(aspect: 1) }

@Suite struct HandlePickerTests {
    @Test func seededSetsMatchTheReference() throws {
        var random = SplitMix64(seed: 2_022)
        var picked = 0
        var empty = 0
        var behind = 0
        var duplicates = 0
        var tiedPicks = 0
        for _ in 0..<200 {
            let target = Vec3(random.uniform(-5...5), random.uniform(-5...5), random.uniform(-5...5))
            let camera = OrbitCamera(target: target, distance: random.uniform(2...20), yaw: random.uniform(-3...3),
                                     pitch: random.uniform(-1.4...1.4), fovY: random.uniform(0.5...1.5))
            let viewport = Vec2(random.uniform(200...1_400), random.uniform(200...1_400))
            let viewProjection = camera.viewProjection(aspect: viewport.x / viewport.y)
            let spread = camera.distance * 1.6
            let count = random.integer(1...40)
            var handles: [SpatialHandle] = []
            for id in 0..<count {
                var position = target + Vec3(random.uniform(-spread...spread), random.uniform(-spread...spread),
                                             random.uniform(-spread...spread))
                let mode = random.integer(0...9)
                if mode == 0 && !handles.isEmpty {
                    position = handles[random.integer(0...(handles.count - 1))].position
                    duplicates += 1
                } else if mode == 1 && !handles.isEmpty {
                    let base = handles[random.integer(0...(handles.count - 1))].position
                    position = base + Vec3(random.uniform(-0.05...0.05), random.uniform(-0.05...0.05),
                                           random.uniform(-0.05...0.05))
                }
                let hitRadius: Double = random.integer(0...2) == 0 ? random.uniform(0...80) : 0
                let kindRoll = random.integer(0...3)
                var kind: HandleKind = .point
                if kindRoll == 1 { kind = .axis(Vec3(1, 0, 0)) }
                if kindRoll == 2 { kind = .plane(Vec3(0, 1, 0)) }
                if kindRoll == 3 { kind = .rotation(Vec3(0, 0, 1)) }
                let handle = try SpatialHandle(id: id, position: position, kind: kind, hitRadius: hitRadius)
                if ScreenProjection.project(position, viewProjection: viewProjection, viewport: viewport) == nil {
                    behind += 1
                }
                handles.append(handle)
            }
            for touchNumber in 0..<8 {
                var touch = Vec2(random.uniform(0...viewport.x), random.uniform(0...viewport.y))
                if touchNumber % 2 == 0 {
                    let aim = handles[random.integer(0...(handles.count - 1))].position
                    if let projected = ScreenProjection.project(aim, viewProjection: viewProjection,
                                                                viewport: viewport) {
                        touch = projected.point + Vec2(random.uniform(-15...15), random.uniform(-15...15))
                        if touchNumber == 0 { touch = projected.point }
                    }
                }
                let touchRadius: Double = random.integer(0...1) == 0 ? random.uniform(0...60) : 22
                let expected = referencePick(handles, touch: touch, viewProjection: viewProjection,
                                             viewport: viewport, touchRadius: touchRadius)
                let actual = try HandlePicker.pick(handles, at: touch, viewProjection: viewProjection,
                                                   viewport: viewport, touchRadius: touchRadius)
                #expect(actual == expected)
                if let index = actual {
                    picked += 1
                    var sameSpot = 0
                    for other in handles where other.position == handles[index].position { sameSpot += 1 }
                    if sameSpot > 1 { tiedPicks += 1 }
                } else {
                    empty += 1
                }
            }
        }
        // The seeded sets exercise every branch of the rule.
        #expect(picked > 400)
        #expect(empty > 100)
        #expect(behind > 50)
        #expect(duplicates > 50)
        #expect(tiedPicks > 5)
    }

    @Test func samePointAtTwoDepthsPicksTheNearer() throws {
        let far = try SpatialHandle(id: 10, position: Vec3(0, 0, -2))
        let near = try SpatialHandle(id: 11, position: Vec3(0, 0, 0))
        let handles: [SpatialHandle] = [far, near]
        let vp = frontViewProjection()
        let a = try #require(ScreenProjection.project(far.position, viewProjection: vp, viewport: squareViewport))
        let b = try #require(ScreenProjection.project(near.position, viewProjection: vp, viewport: squareViewport))
        #expect(a.point == b.point)
        #expect(b.depth < a.depth)
        #expect(try HandlePicker.pick(handles, at: center, viewProjection: vp, viewport: squareViewport) == 1)
        let offset = Vec2(207, 196)
        #expect(try HandlePicker.pick(handles, at: offset, viewProjection: vp, viewport: squareViewport) == 1)
    }

    @Test func samePositionTwicePicksTheLowerIndex() throws {
        let other = try SpatialHandle(id: 1, position: Vec3(3, 3, 0))
        let first = try SpatialHandle(id: 2, position: Vec3(0.1, 0, 0))
        let second = try SpatialHandle(id: 3, position: Vec3(0.1, 0, 0), kind: .axis(Vec3(0, 1, 0)))
        let handles: [SpatialHandle] = [other, first, second]
        let vp = frontViewProjection()
        #expect(try HandlePicker.pick(handles, at: center, viewProjection: vp, viewport: squareViewport) == 1)
        let swapped: [SpatialHandle] = [other, second, first]
        #expect(try HandlePicker.pick(swapped, at: center, viewProjection: vp, viewport: squareViewport) == 1)
    }

    @Test func nearerOnScreenBeatsNearerInDepth() throws {
        let vp = frontViewProjection()
        let deep = try SpatialHandle(id: 0, position: Vec3(0, 0, -3))
        let shallow = try SpatialHandle(id: 1, position: Vec3(0.1, 0, 2))
        let shallowPoint = try #require(ScreenProjection.project(shallow.position, viewProjection: vp,
                                                                viewport: squareViewport)).point
        #expect((shallowPoint - center).length < 22)
        #expect(try HandlePicker.pick([shallow, deep], at: center, viewProjection: vp, viewport: squareViewport) == 1)
    }

    @Test func handlesBehindTheCameraOrOutsideTheDepthRangeAreSkipped() throws {
        let vp = frontViewProjection()
        // Behind the eye at z = 5 on the view axis: a naive divide by w would land on the centre.
        let behind = try SpatialHandle(id: 0, position: Vec3(0, 0, 8), hitRadius: 500)
        #expect(ScreenProjection.project(behind.position, viewProjection: vp, viewport: squareViewport) == nil)
        let naive = vp * Vec4(behind.position, 1)
        #expect(naive.w < 0)
        #expect(abs(naive.x / naive.w) < 1e-9 && abs(naive.y / naive.w) < 1e-9)
        #expect(try HandlePicker.pick([behind], at: center, viewProjection: vp, viewport: squareViewport) == nil)
        // In front of the eye but nearer than the near plane, and beyond the far plane.
        let tooNear = try SpatialHandle(id: 1, position: Vec3(0, 0, 4.95))
        let tooFar = try SpatialHandle(id: 2, position: Vec3(0, 0, -2_000))
        let nearDepth = try #require(ScreenProjection.project(tooNear.position, viewProjection: vp,
                                                             viewport: squareViewport)).depth
        let farDepth = try #require(ScreenProjection.project(tooFar.position, viewProjection: vp,
                                                            viewport: squareViewport)).depth
        #expect(nearDepth < -1)
        #expect(farDepth > 1)
        let skipped: [SpatialHandle] = [behind, tooNear, tooFar]
        #expect(try HandlePicker.pick(skipped, at: center, viewProjection: vp, viewport: squareViewport) == nil)
        let visible = try SpatialHandle(id: 3, position: Vec3(0.2, 0, 0))
        let mixed: [SpatialHandle] = [behind, tooNear, tooFar, visible]
        #expect(try HandlePicker.pick(mixed, at: center, viewProjection: vp, viewport: squareViewport) == 3)
    }

    @Test func nothingWithinTheRadiusPicksNothing() throws {
        let vp = frontViewProjection()
        let handle = try SpatialHandle(id: 0, position: .zero)
        #expect(try HandlePicker.pick([handle], at: Vec2(200, 240), viewProjection: vp, viewport: squareViewport) == nil)
        #expect(try HandlePicker.pick([], at: center, viewProjection: vp, viewport: squareViewport) == nil)
    }

    @Test func smallTouchRadiiAreRaisedAndHitRadiiWiden() throws {
        let vp = frontViewProjection()
        let handle = try SpatialHandle(id: 0, position: .zero)
        let handles: [SpatialHandle] = [handle]
        for radius in [5.0, 0, -10, 22] {
            #expect(try HandlePicker.pick(handles, at: Vec2(220, 200), viewProjection: vp, viewport: squareViewport,
                                          touchRadius: radius) == 0)
            #expect(try HandlePicker.pick(handles, at: Vec2(223, 200), viewProjection: vp, viewport: squareViewport,
                                          touchRadius: radius) == nil)
        }
        for radius in [Double.nan, .infinity, -.infinity] {
            #expect(try HandlePicker.pick(handles, at: Vec2(220, 200), viewProjection: vp, viewport: squareViewport,
                                          touchRadius: radius) == 0)
            #expect(try HandlePicker.pick(handles, at: Vec2(223, 200), viewProjection: vp, viewport: squareViewport,
                                          touchRadius: radius) == nil)
        }
        #expect(try HandlePicker.pick(handles, at: Vec2(240, 200), viewProjection: vp, viewport: squareViewport,
                                      touchRadius: 45) == 0)
        let wide = try SpatialHandle(id: 1, position: .zero, hitRadius: 60)
        #expect(try HandlePicker.pick([wide], at: Vec2(250, 200), viewProjection: vp, viewport: squareViewport) == 0)
        #expect(try HandlePicker.pick([wide], at: Vec2(261, 200), viewProjection: vp, viewport: squareViewport) == nil)
    }

    @Test func nonFiniteTouchPicksNothing() throws {
        let vp = frontViewProjection()
        let handle = try SpatialHandle(id: 0, position: .zero, hitRadius: 1_000)
        let touches: [Vec2] = [Vec2(.nan, 200), Vec2(200, .infinity), Vec2(-.infinity, .nan)]
        for touch in touches {
            #expect(try HandlePicker.pick([handle], at: touch, viewProjection: vp, viewport: squareViewport) == nil)
        }
    }

    @Test func refusalsAndReasonCodes() throws {
        let vp = frontViewProjection()
        let handle = try SpatialHandle(id: 0, position: .zero)
        let full = [SpatialHandle](repeating: handle, count: 1_024)
        #expect(try HandlePicker.pick(full, at: center, viewProjection: vp, viewport: squareViewport) == 0)
        let over = [SpatialHandle](repeating: handle, count: 1_025)
        #expect(throws: SpatialControlError.handleLimit) {
            _ = try HandlePicker.pick(over, at: center, viewProjection: vp, viewport: squareViewport)
        }
        let badViewports: [Vec2] = [Vec2(0, 400), Vec2(400, 0), Vec2(-1, 400), Vec2(400, -1), Vec2(.nan, 400),
                                    Vec2(400, .infinity)]
        for viewport in badViewports {
            #expect(throws: SpatialControlError.viewport) {
                _ = try HandlePicker.pick([handle], at: center, viewProjection: vp, viewport: viewport)
            }
            #expect(throws: SpatialControlError.viewport) {
                _ = try HandlePicker.pick([handle], at: Vec2(.nan, 0), viewProjection: vp, viewport: viewport)
            }
        }
        #expect(SpatialControlError.handleLimit.reasonCode == "r2-f22.handle-limit")
        #expect(SpatialControlError.viewport.reasonCode == "r2-f22.viewport")
        #expect(SpatialControlError.parameter("kind").reasonCode == "r2-f22.parameter")
    }

    @Test func handleRefusals() throws {
        let badPositions: [Vec3] = [Vec3(.nan, 0, 0), Vec3(0, .infinity, 0), Vec3(0, 0, -.infinity)]
        for position in badPositions {
            #expect(throws: SpatialControlError.parameter("position")) {
                _ = try SpatialHandle(id: 0, position: position)
            }
        }
        let badRadii: [Double] = [-1, -.ulpOfOne, .nan, .infinity, -.infinity]
        for radius in badRadii {
            #expect(throws: SpatialControlError.parameter("hitRadius")) {
                _ = try SpatialHandle(id: 0, position: .zero, hitRadius: radius)
            }
        }
        let badKinds: [HandleKind] = [.axis(.zero), .plane(.zero), .rotation(.zero), .axis(Vec3(.nan, 0, 0)),
                                      .plane(Vec3(0, .infinity, 0)), .rotation(Vec3(0, 0, -.infinity))]
        for kind in badKinds {
            #expect(throws: SpatialControlError.parameter("kind")) {
                _ = try SpatialHandle(id: 0, position: .zero, kind: kind)
            }
        }
        let zeroRadius = try SpatialHandle(id: -4, position: Vec3(1, 2, 3), kind: .point, hitRadius: 0)
        #expect(zeroRadius.id == -4 && zeroRadius.kind == .point && zeroRadius.hitRadius == 0)
        let defaults = try SpatialHandle(id: 9, position: .zero)
        #expect(defaults.kind == .point && defaults.hitRadius == 0)
        #expect(SpatialControlError.parameter("hitRadius").reasonCode == "r2-f22.parameter")
    }

    @Test func handlesRoundTripAndBadHandlesAreRefusedOnDecode() throws {
        let handles: [SpatialHandle] = [
            try SpatialHandle(id: 0, position: Vec3(1, -2, 3.5)),
            try SpatialHandle(id: 1, position: Vec3(0, 0, 0), kind: .axis(Vec3(1, 0, 0)), hitRadius: 30),
            try SpatialHandle(id: 2, position: Vec3(-0.25, 4, 1e-9), kind: .plane(Vec3(0, 2, 0)), hitRadius: 0.5),
            try SpatialHandle(id: 3, position: Vec3(7, 7, 7), kind: .rotation(Vec3(0, 0, -1)), hitRadius: 80),
        ]
        let data = try JSONEncoder().encode(handles)
        let decoded = try JSONDecoder().decode([SpatialHandle].self, from: data)
        #expect(decoded == handles)

        let valid = try JSONEncoder().encode(handles[1])
        var object = try #require(try JSONSerialization.jsonObject(with: valid) as? [String: Any])
        object["hitRadius"] = -1
        let negative = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(SpatialHandle.self, from: negative) }

        var zeroKind = try #require(try JSONSerialization.jsonObject(with: valid) as? [String: Any])
        let kindData = try JSONEncoder().encode(HandleKind.axis(.zero))
        zeroKind["kind"] = try JSONSerialization.jsonObject(with: kindData)
        let zeroData = try JSONSerialization.data(withJSONObject: zeroKind)
        #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(SpatialHandle.self, from: zeroData) }

        let restored = try JSONSerialization.data(withJSONObject: try JSONSerialization.jsonObject(with: valid))
        #expect(try JSONDecoder().decode(SpatialHandle.self, from: restored) == handles[1])
    }
}
