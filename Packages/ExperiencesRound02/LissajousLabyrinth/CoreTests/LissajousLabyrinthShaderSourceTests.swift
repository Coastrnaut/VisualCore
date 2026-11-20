// LissajousLabyrinthShaderSourceTests — feature 313 (R02-G02-03) T-R02G0203-003 (FR-R02G0203-001, FR-R02G0203-002;
// research R1, R3). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, every declared
// uniform listed, used and declared once per program, no texture sampler and no loops, vertex outputs matching fragment
// inputs, balanced braces, the `ShaderMeshRenderer` attribute names and locations, ASCII only, and the CPU references
// (head and trail fractions, solid colour, the thread's depth fade and its range, T-R02G0203-014). The real compile happens on the simulator.
// The version literal "#version 300 es" is VisualCoreShaderSource's `ShaderLibrary.versionLine`; the attributes
// `a_position` at 0, `a_normal` at 1 and `a_uv` at 2 are VisualCoreRendering's `ShaderMeshRenderer` streams (neither is a
// dependency of this target). Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreMath

@Suite struct LissajousLabyrinthShaderSourceTests {
    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "thread", vertex: LissajousLabyrinthShaders.threadVertex,
                 fragment: LissajousLabyrinthShaders.threadFragment, uniforms: LissajousLabyrinthShaders.threadUniforms),
         Program(name: "solid", vertex: LissajousLabyrinthShaders.solidVertex,
                 fragment: LissajousLabyrinthShaders.solidFragment, uniforms: LissajousLabyrinthShaders.solidUniforms)]
    }

    static func sources() -> [String] {
        [LissajousLabyrinthShaders.threadVertex, LissajousLabyrinthShaders.threadFragment,
         LissajousLabyrinthShaders.solidVertex, LissajousLabyrinthShaders.solidFragment]
    }

    /// Trimmed non-empty lines of `source`.
    static func lines(_ source: String) -> [String] {
        var result: [String] = []
        for raw in source.split(separator: "\n", omittingEmptySubsequences: true) {
            let line: String = raw.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { result.append(line) }
        }
        return result
    }

    /// Whitespace-separated tokens of a declaration line without its trailing semicolon.
    static func tokens(_ line: String) -> [String] {
        var body: String = line
        if body.hasSuffix(";") { body.removeLast() }
        var result: [String] = []
        for token in body.split(whereSeparator: { $0 == " " || $0 == "\t" }) { result.append(String(token)) }
        return result
    }

    /// Names (last token) of the declarations in `source` starting with `keyword` and a space.
    static func declared(_ keyword: String, in source: String) -> [String] {
        var names: [String] = []
        for line in lines(source) where line.hasPrefix(keyword + " ") {
            let parts: [String] = tokens(line)
            if let last = parts.last { names.append(last) }
        }
        return names
    }

    /// (name, type) of the stage interface declarations starting with `keyword` (`in` or `out`); layout lines excluded.
    static func interface(_ keyword: String, in source: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in lines(source) where line.hasPrefix(keyword + " ") {
            let parts: [String] = tokens(line)
            if parts.count >= 3 { result[parts[parts.count - 1]] = parts[parts.count - 2] }
        }
        return result
    }

    /// "location name type" of the `layout(location = n) in type name;` lines of `source`, in order.
    static func layouts(_ source: String) -> [String] {
        var result: [String] = []
        for line in lines(source) where line.hasPrefix("layout(location = ") {
            let parts: [String] = tokens(line)
            result.append("\(String(parts[2].dropLast())) \(parts[parts.count - 1]) \(parts[parts.count - 2])")
        }
        return result
    }

    /// Occurrences of `word` in `text` as a whole identifier.
    static func wordCount(_ word: String, in text: String) -> Int {
        let chars: [Character] = Array(text)
        let target: [Character] = Array(word)
        var count: Int = 0
        var i: Int = 0
        while i + target.count <= chars.count {
            var match: Bool = true
            var k: Int = 0
            while k < target.count {
                if chars[i + k] != target[k] { match = false; break }
                k += 1
            }
            if match {
                let before: Bool = i > 0 && (chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
                let end: Int = i + target.count
                let after: Bool = end < chars.count && (chars[end].isLetter || chars[end].isNumber || chars[end] == "_")
                if !before && !after { count += 1 }
            }
            i += 1
        }
        return count
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(LissajousLabyrinthShaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func everyUniformIsListedDeclaredOnceAndUsed() {
        for program in Self.programs() {
            let declared: [String] = Self.declared("uniform", in: program.vertex)
                + Self.declared("uniform", in: program.fragment)
            #expect(declared == program.uniforms, "\(program.name) declares in a different order or set")
            #expect(Set(program.uniforms).count == program.uniforms.count, "\(program.name) list has duplicates")
            #expect(LissajousLabyrinthShaders.uniformNames[program.name] == program.uniforms)
            for name in program.uniforms {
                let uses: Int = Self.wordCount(name, in: program.vertex) + Self.wordCount(name, in: program.fragment)
                #expect(uses >= 2, "\(program.name) never uses \(name)")
            }
        }
        #expect(LissajousLabyrinthShaders.uniformNames.count == 2)
    }

    @Test func requiredUniformsAreDeclaredWithTheirTypes() {
        let thread: String = LissajousLabyrinthShaders.threadVertex + LissajousLabyrinthShaders.threadFragment
        let threadDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform float u_head;", "uniform float u_trail;", "uniform float u_glow;",
            "uniform float u_opacity;", "uniform float u_time;", "uniform vec3 u_cobalt;", "uniform vec3 u_violet;",
            "uniform vec3 u_copper;",
        ]
        for declaration in threadDeclarations { #expect(thread.contains(declaration), "\(declaration)") }
        let solid: String = LissajousLabyrinthShaders.solidVertex + LissajousLabyrinthShaders.solidFragment
        let solidDeclarations: [String] = [
            "uniform mat4 u_mvp;", "uniform vec3 u_color;", "uniform float u_lit;", "uniform float u_opacity;",
            "uniform float u_rim;", "uniform vec3 u_viewDir;",
        ]
        for declaration in solidDeclarations { #expect(solid.contains(declaration), "\(declaration)") }
    }

    @Test func noTextureSamplerAndNoLoops() {
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture("))
            #expect(Self.wordCount("for", in: source) == 0)
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
        }
    }

    @Test func bracesAndParenthesesAreBalanced() {
        for source in Self.sources() {
            var braces: Int = 0
            var parens: Int = 0
            var negative: Bool = false
            for c in source {
                if c == "{" { braces += 1 }
                if c == "}" { braces -= 1 }
                if c == "(" { parens += 1 }
                if c == ")" { parens -= 1 }
                if braces < 0 || parens < 0 { negative = true }
            }
            #expect(braces == 0)
            #expect(parens == 0)
            #expect(!negative)
            #expect(source.contains("void main() {"))
        }
    }

    @Test func vertexOutputsMatchFragmentInputs() {
        for program in Self.programs() {
            let outs: [String: String] = Self.interface("out", in: program.vertex)
            let ins: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outs == ins, "\(program.name)")
            let fragmentOuts: [String: String] = Self.interface("out", in: program.fragment)
            #expect(fragmentOuts == ["color": "vec4"], "\(program.name)")
            #expect(program.fragment.contains("color = vec4(rgb * alpha, alpha);"), "\(program.name) premultiplied")
        }
        #expect(Self.interface("out", in: LissajousLabyrinthShaders.threadVertex)
                == ["v_lap": "float", "v_side": "float", "v_fade": "float"])
        #expect(Self.interface("out", in: LissajousLabyrinthShaders.solidVertex) == ["v_normal": "vec3"])
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        var listed: [String] = []
        for attribute in LissajousLabyrinthShaders.attributes { listed.append("\(attribute.location) \(attribute.name)") }
        #expect(listed == ["0 a_position", "1 a_normal", "2 a_uv"])
        #expect(Self.layouts(LissajousLabyrinthShaders.threadVertex)
                == ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"])
        #expect(Self.layouts(LissajousLabyrinthShaders.solidVertex) == ["0 a_position vec3", "1 a_normal vec3"])
        #expect(Self.layouts(LissajousLabyrinthShaders.threadFragment).isEmpty)
        #expect(Self.layouts(LissajousLabyrinthShaders.solidFragment).isEmpty)
        #expect(LissajousLabyrinthShaders.threadVertex.contains("v_lap = a_uv.x;"))
        #expect(LissajousLabyrinthShaders.threadVertex.contains("v_side = a_uv.y;"))
    }

    @Test func sourcesAreASCII() {
        for source in Self.sources() {
            var nonASCII: Int = 0
            for scalar in source.unicodeScalars where !scalar.isASCII { nonASCII += 1 }
            #expect(nonASCII == 0)
        }
    }

    @Test func boundsMatchTheShaderConstants() {
        #expect(LissajousLabyrinthShaders.maxGlow == 4.0)
        #expect(LissajousLabyrinthShaders.threadFragment.contains("clamp(u_glow, 0.0, 4.0)"))
        #expect(LissajousLabyrinthShaders.solidDimShare == 0.5)
        #expect(LissajousLabyrinthShaders.solidFragment.contains("mix(0.5, 1.0,"))
    }

    @Test func headAndTrailFractionsWrapIntoTheLap() {
        #expect(LissajousLabyrinthShaders.headFraction(tick: 0) == 0)
        #expect(LissajousLabyrinthShaders.headFraction(tick: 1_024) == 0.25)
        #expect(LissajousLabyrinthShaders.headFraction(tick: 4_096) == 0)
        #expect(LissajousLabyrinthShaders.headFraction(tick: -1_024) == 0.75)
        for tick in stride(from: -9_000, through: 9_000, by: 337) {
            let fraction: Double = LissajousLabyrinthShaders.headFraction(tick: tick)
            #expect(fraction >= 0 && fraction < 1)
        }
        let expected: [Double] = [0.125, 0.0625, 0.03125]
        var index: Int = 0
        for tier in LissajousLabyrinthTier.all {
            #expect(LissajousLabyrinthShaders.trailFraction(tier) == expected[index])
            index += 1
        }
    }

    @Test func solidColourIsTheFacingColour() {
        let copper: SIMD3<Double> = LissajousLabyrinthPalette.copper
        #expect(LissajousLabyrinthShaders.solidColour(copper, lit: true) == copper)
        #expect(LissajousLabyrinthShaders.solidColour(copper, lit: false) == copper * 0.5)
        let over: SIMD3<Double> = SIMD3<Double>(1.5, -0.2, 0.5)
        #expect(LissajousLabyrinthShaders.solidColour(over, lit: true) == SIMD3<Double>(1, 0, 0.5))
    }

    @Test func depthFadeBrightensTheFrontAndKeepsTheBack() {
        let gain: Double = LissajousLabyrinthShaders.depthFadeGain
        #expect(gain == 0.15)
        #expect(abs(LissajousLabyrinthShaders.depthFade(eyeDistance: 2, near: 2, far: 4) - 1.15) < 1e-12)
        #expect(abs(LissajousLabyrinthShaders.depthFade(eyeDistance: 1, near: 2, far: 4) - 1.15) < 1e-12)
        #expect(LissajousLabyrinthShaders.depthFade(eyeDistance: 4, near: 2, far: 4) == 1)
        #expect(LissajousLabyrinthShaders.depthFade(eyeDistance: 9, near: 2, far: 4) == 1)
        #expect(abs(LissajousLabyrinthShaders.depthFade(eyeDistance: 3, near: 2, far: 4) - 1.075) < 1e-12)
        #expect(LissajousLabyrinthShaders.depthFade(eyeDistance: .nan, near: 2, far: 4) == 1)
        var previous: Double = 1 + gain
        for step in 0...40 {
            let fade: Double = LissajousLabyrinthShaders.depthFade(eyeDistance: 2 + Double(step) * 0.05, near: 2, far: 4)
            #expect(fade <= previous && fade >= 1)
            previous = fade
        }
        #expect(LissajousLabyrinthShaders.threadVertex.contains("mix(1.15, 1.0, depth)"))
        #expect(LissajousLabyrinthShaders.threadFragment.contains("clamp(v_fade, 1.0, 1.15)"))
    }

    @Test func depthRangeBracketsTheFigureAtEveryAspect() throws {
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(
            LissajousLabyrinthManifest.entries[0])
        let snapshot: LissajousLabyrinthSceneSnapshot = LissajousLabyrinthSceneSnapshot(
            play: LissajousLabyrinthPlay(level: generated.level), time: 0)
        let b = LissajousLabyrinthSceneGeometry.bounds(snapshot)
        let aspects: [Double] = [0.4, 0.75, 1, 1.5, 2.5, 0, .nan]
        for aspect in aspects {
            let range = LissajousLabyrinthSceneGeometry.depthRange(aspect: aspect, snapshot: snapshot)
            let eye = LissajousLabyrinthSceneGeometry.camera(aspect: aspect, snapshot: snapshot).eye
            #expect(range.near > 0 && range.far > range.near)
            #expect(abs((range.far - range.near) - 2 * b.radius) < 1e-9)
            let front: Double = (b.centre - eye).length - b.radius
            #expect(abs(front - range.near) < 1e-9 || range.near == 1e-3)
        }
    }
}
