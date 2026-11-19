// ProgramRenderTests — feature 180 (A25-P01) T-A25-108 (FR-A25-104, FR-A25-107; SC-A25-104; clarifications Q1, Q4;
// research R2). Inside a `RenderHost` scene every effect's program compiles with `FieldPass`; the test image uploads
// into an `.rgba8` target and reads back byte for byte; and each effect drawn at its defaults and at one non-default
// setting matches the CPU reference within 2/255 per channel (4/255 for `distort`, which samples between texel
// centres). The checked pixels are every pixel of the 64 × 64 picture, except for `posterize`, whose pixels with a
// channel within 1/255 of a level edge are left out (clarification Q4). The largest difference is printed.
import Testing
import VisualCoreRendering
import EffectsComposerCore

/// One effect setting checked against its reference.
struct RenderCase: Sendable, CustomStringConvertible {
    /// The effect.
    let effect: EffectID
    /// The values changed from the defaults (empty: the defaults).
    let values: [String: Double]

    /// The node drawn.
    var node: EffectNode {
        var node = EffectNode(id: 1, effect: effect)
        for (name, value) in values { node.values[name] = value }
        return node
    }

    /// The largest allowed channel difference in 8-bit steps.
    var tolerance: Int { effect == .distort ? 4 : 2 }

    /// "effect values".
    var description: String {
        "\(effect.rawValue) " + (values.isEmpty ? "defaults" : values.keys.sorted().map { "\($0)=\(values[$0]!)" }
            .joined(separator: ","))
    }

    /// The defaults and one non-default setting of every effect, plus blur at its largest radius.
    static let all: [RenderCase] = [
        RenderCase(effect: .grade, values: [:]),
        RenderCase(effect: .grade, values: ["exposure": 0.5, "contrast": 1.5, "saturation": 0.4]),
        RenderCase(effect: .blur, values: [:]),
        RenderCase(effect: .blur, values: ["radius": 3]),
        RenderCase(effect: .blur, values: ["radius": 8]),
        RenderCase(effect: .distort, values: [:]),
        RenderCase(effect: .distort, values: ["amplitude": 0.03, "frequency": 3]),
        RenderCase(effect: .vignette, values: [:]),
        RenderCase(effect: .vignette, values: ["amount": 1, "radius": 0.6, "softness": 0.4]),
        RenderCase(effect: .posterize, values: [:]),
        RenderCase(effect: .posterize, values: ["levels": 4]),
    ]
}

@MainActor
@Suite(.serialized) struct ProgramRenderTests {
    @Test func everyProgramCompilesAndTheTestImageRoundTrips() throws {
        let image = TestImage.make()
        let (compiled, roundTrip) = try EffectHost.run { context -> (Int, RGBAImage) in
            let drawer = try EffectDrawer(registry: context.resources)
            defer { drawer.release() }
            let target = try drawer.upload(image)
            defer { context.resources.release(target) }
            return (drawer.passes.count, try drawer.read(target))
        }
        #expect(compiled == EffectID.allCases.count)
        #expect(roundTrip == image, "the upload stores n/255 exactly and the read-back flips rows back")
    }

    @Test func everyProgramDeclaresTheSourceInputAndOnlyTheUniformsItUses() {
        for effect in EffectID.allCases {
            let source = EffectPrograms.source(for: effect)
            #expect(source.contains("uniform highp sampler2D u_source;"), "\(effect)")
            #expect(!source.contains("#version"), "FieldPass adds the version line")
            let names = EffectPrograms.uniforms(for: EffectNode(id: 1, effect: effect), width: 64, height: 64).keys
            for name in names { #expect(source.contains(name), "\(effect) \(name)") }
            #expect(names.contains("u_params"))
            #expect(names.contains("u_texel") == (effect == .blur))
        }
        let texel = EffectPrograms.uniforms(for: EffectNode(id: 1, effect: .blur), width: 64, height: 32)["u_texel"]
        #expect(texel == [0.015625, 0.03125], "1/64 and 1/32")
    }

    @Test(arguments: RenderCase.all)
    func theProgramMatchesItsReference(_ renderCase: RenderCase) throws {
        let image = TestImage.make()
        let node = renderCase.node
        let gpu = try EffectHost.run { context -> RGBAImage in
            let drawer = try EffectDrawer(registry: context.resources)
            defer { drawer.release() }
            return try drawer.draw(node, on: image)
        }
        let reference = EffectReference.apply(node, to: image)
        let include: (Int, Int) -> Bool
        if renderCase.effect == .posterize {
            let steps = Float((node.values["levels"] ?? 8).rounded() - 1)
            include = { x, y in
                (0..<3).allSatisfy { c in
                    let t = Float(image[x, y, c]) / 255 * steps + 0.5
                    return abs(t - t.rounded()) >= steps / 255
                }
            }
        } else {
            include = { _, _ in true }
        }
        let diff = PictureCompare.maxDifference(gpu, reference, include: include)
        print("a25-render \(renderCase): max channel difference \(diff.max)/255 over \(diff.compared) pixels")
        #expect(diff.compared >= 64 * 64 / 2, "\(renderCase): enough pixels checked (\(diff.compared))")
        #expect(diff.max <= renderCase.tolerance, "\(renderCase): \(diff.max)/255 > \(renderCase.tolerance)/255")
        if !(renderCase.effect == .grade && renderCase.values.isEmpty) {
            #expect(reference != image, "\(renderCase) changes the picture")
        }
    }
}
