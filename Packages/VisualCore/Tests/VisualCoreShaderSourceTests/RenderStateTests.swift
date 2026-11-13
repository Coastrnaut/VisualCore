// RenderStateTests — feature 204 R02-F04 T-R02F04-006 (US2; FR-R02F04-020, -023, -024): the pure pipeline state is
// host-testable; presets carry exactly the fields of data-model.md; equal values compare and hash equal.
import Testing
import VisualCoreShaderSource

@Test func opaquePresetHasNoBlendNoDepthNoCullAndAllChannels() {
    let s = RenderState.opaque
    #expect(s.blend == .none)
    #expect(s.depthTest == false)
    #expect(s.depthWrite == false)
    #expect(s.cull == .none)
    #expect(s.colorMask == .all)
}

@Test func alphaBlendedPresetOnlyChangesTheBlendMode() {
    let s = RenderState.alphaBlended
    #expect(s.blend == .alpha)
    #expect(s.depthTest == false)
    #expect(s.depthWrite == false)
    #expect(s.cull == .none)
    #expect(s.colorMask == .all)
}

@Test func additivePresetBlendsAdditivelyWithoutDepthWrite() {
    let s = RenderState.additive
    #expect(s.blend == .additive)
    #expect(s.depthTest == false)
    #expect(s.depthWrite == false)
    #expect(s.cull == .none)
    #expect(s.colorMask == .all)
}

@Test func opaque3DPresetTestsAndWritesDepthAndCullsBackFaces() {
    let s = RenderState.opaque3D
    #expect(s.blend == .none)
    #expect(s.depthTest == true)
    #expect(s.depthWrite == true)
    #expect(s.cull == .back)
    #expect(s.colorMask == .all)
}

@Test func colorMaskAllEnablesEveryChannel() {
    let m = RenderState.ColorMask.all
    #expect(m.red && m.green && m.blue && m.alpha)
    #expect(RenderState.ColorMask(red: true, green: false, blue: true, alpha: true) != .all)
}

@Test func defaultInitializerEqualsTheOpaquePreset() {
    #expect(RenderState() == .opaque)
}

@Test func equalValuesCompareAndHashEqual() {
    let a = RenderState(blend: .premultiplied, depthTest: true, depthWrite: false, cull: .front,
                        colorMask: RenderState.ColorMask(red: true, green: true, blue: false, alpha: false))
    let b = RenderState(blend: .premultiplied, depthTest: true, depthWrite: false, cull: .front,
                        colorMask: RenderState.ColorMask(red: true, green: true, blue: false, alpha: false))
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
    var c = b
    c.depthWrite = true
    #expect(a != c)
    #expect(Set([a, b, c]).count == 2)
}

@Test func theFourPresetsAreDistinctCacheKeys() {
    let presets: Set<RenderState> = [.opaque, .alphaBlended, .additive, .opaque3D]
    #expect(presets.count == 4)
    let again: Set<RenderState> = [.opaque, .alphaBlended, .additive, .opaque3D, .opaque, RenderState()]
    #expect(again.count == 4)
}
