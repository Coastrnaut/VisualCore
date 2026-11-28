// MyceliumArchitectShaderSourceTests — feature 513 (R02-G22-03) T-R02G2203-004 (FR-R02G2203-001, 002; clarifications
// Q3–Q5; research R6, R7). Host checks of the GLSL ES 3.00 sources: the version line and one precision statement, the
// attribute names and locations (the `ShaderMeshRenderer` streams), every declared uniform listed and used in its
// stage, the time input only in the board vertex stage and multiplied by the motion (Reduce Motion), at most 16 vec4
// uniform slots per program (board 7, glow 7) equal to `uniformSlots`, no texture sampler and no `discard`, only
// `for` loops with a constant integer bound (no `while`, no `do`), no reserved word used as a name, vertex outputs
// matching fragment inputs, balanced braces, ASCII-only sources, every palette hex written as its vec3 constant and
// matching `MyceliumArchitectPalette` within 1/255, every material code (0 … 23) selected by the vertex shader and
// decoded by the fragment shader, the value and broken mark round trip in uv, the backdrop spores covering at most 2 %,
// the glow gain capped by the limit, no random or time-of-day source, the source file's own text (no MetalKit import),
// and, when `glslangValidator` is installed, a real front-end compile (skipped otherwise). Explicit types, plain loops.
import Foundation
import Testing
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectShaderSourceTests {
    typealias Shaders = MyceliumArchitectShaders
    typealias Palette = MyceliumArchitectPalette
    typealias Material = MyceliumArchitectShaderMaterial

    struct Program {
        let name: String
        let vertex: String
        let fragment: String
        let uniforms: [String]
    }

    static func programs() -> [Program] {
        [Program(name: "board", vertex: Shaders.boardVertex, fragment: Shaders.boardFragment,
                 uniforms: Shaders.boardUniforms),
         Program(name: "glow", vertex: Shaders.glowVertex, fragment: Shaders.glowFragment,
                 uniforms: Shaders.glowUniforms)]
    }

    static func sources() -> [String] {
        [Shaders.boardVertex, Shaders.boardFragment, Shaders.glowVertex, Shaders.glowFragment]
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

    /// (type, name) of the declarations in `source` starting with `keyword` and a space.
    static func declarations(_ keyword: String, in source: String) -> [(type: String, name: String)] {
        var result: [(type: String, name: String)] = []
        for line in lines(source) where line.hasPrefix("\(keyword) ") {
            let parts: [String] = tokens(line)
            guard parts.count >= 3 else { continue }
            result.append((type: parts[parts.count - 2], name: parts[parts.count - 1]))
        }
        return result
    }

    /// Names of the declarations in `source` starting with `keyword` and a space.
    static func declared(_ keyword: String, in source: String) -> [String] {
        var names: [String] = []
        for declaration in declarations(keyword, in: source) { names.append(declaration.name) }
        return names
    }

    /// (name, type) of the stage interface declarations starting with `keyword` (`in` or `out`).
    static func interface(_ keyword: String, in source: String) -> [String: String] {
        var result: [String: String] = [:]
        for declaration in declarations(keyword, in: source) { result[declaration.name] = declaration.type }
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

    /// The value of `const vec3 <name> = vec3(a, b, c);` in `source`, nil when absent or malformed.
    static func vec3Constant(_ name: String, in source: String) -> SIMD3<Double>? {
        let prefix: String = "const vec3 \(name) = vec3("
        for line in lines(source) where line.hasPrefix(prefix) && line.hasSuffix(");") {
            let body: String = String(line.dropFirst(prefix.count).dropLast(2))
            var values: [Double] = []
            for part in body.split(separator: ",") {
                guard let value = Double(part.trimmingCharacters(in: .whitespaces)) else { return nil }
                values.append(value)
            }
            guard values.count == 3 else { return nil }
            return SIMD3<Double>(values[0], values[1], values[2])
        }
        return nil
    }

    /// The identifiers of `text` (letters, digits and underscores, starting with a letter or underscore).
    static func identifiers(_ text: String) -> [String] {
        var result: [String] = []
        var current: String = ""
        for c in text {
            if c.isLetter || c == "_" || (c.isNumber && !current.isEmpty) {
                current.append(c)
            } else {
                if !current.isEmpty { result.append(current) }
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Occurrences of `word` in `text` as a whole identifier.
    static func wordCount(_ word: String, in text: String) -> Int {
        var count: Int = 0
        for identifier in identifiers(text) where identifier == word { count += 1 }
        return count
    }

    /// The colour of a `#RRGGBB` hex string as components 0 … 1, nil when malformed.
    static func hexColour(_ hex: String) -> SIMD3<Double>? {
        guard hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        let r: Double = Double((value >> 16) & 0xFF) / 255
        let g: Double = Double((value >> 8) & 0xFF) / 255
        let b: Double = Double(value & 0xFF) / 255
        return SIMD3<Double>(r, g, b)
    }

    /// The largest component difference of `a` and `b`.
    static func gap(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z)))
    }

    @Test func everySourceStartsWithTheVersionLineAndStatesAPrecision() {
        #expect(Shaders.versionLine == "#version 300 es")
        for source in Self.sources() {
            let all: [String] = Self.lines(source)
            #expect(all.first == "#version 300 es")
            var precision: Int = 0
            for line in all where line.hasPrefix("precision ") && line.hasSuffix(" float;") { precision += 1 }
            #expect(precision == 1)
        }
    }

    @Test func attributesFollowTheShaderMeshRendererStreams() {
        #expect(Shaders.attributes.count == 3)
        let expected: [String] = ["0 a_position vec3", "1 a_normal vec3", "2 a_uv vec2"]
        #expect(Self.layouts(Shaders.boardVertex) == expected)
        #expect(Self.layouts(Shaders.glowVertex) == expected)
        #expect(Self.layouts(Shaders.boardFragment).isEmpty)
        #expect(Self.layouts(Shaders.glowFragment).isEmpty)
        var names: [String] = []
        for attribute in Shaders.attributes { names.append("\(attribute.location) \(attribute.name)") }
        #expect(names == ["0 a_position", "1 a_normal", "2 a_uv"])
    }

    @Test func everyUniformIsDeclaredAndUsedAndTimeIsTimesMotion() {
        for program in Self.programs() {
            let vertexDeclared: [String] = Self.declared("uniform", in: program.vertex)
            let fragmentDeclared: [String] = Self.declared("uniform", in: program.fragment)
            #expect(Set(vertexDeclared).isDisjoint(with: Set(fragmentDeclared)), "\(program.name) declares twice")
            #expect(vertexDeclared + fragmentDeclared == program.uniforms, "\(program.name) declares another set")
            #expect(Shaders.uniformNames[program.name] == program.uniforms)
            let stages: [String] = [program.vertex, program.fragment]
            for stage in stages {
                for name in Self.declared("uniform", in: stage) {
                    #expect(Self.wordCount(name, in: stage) >= 2, "\(program.name): \(name) unused in its stage")
                }
            }
        }
        #expect(Shaders.boardUniforms == ["u_mvp", "u_time", "u_motion", "u_won"])
        #expect(Shaders.glowUniforms == ["u_mvp", "u_glowGain", "u_glowLimit", "u_won"])
        #expect(Self.declared("uniform", in: Shaders.boardFragment).isEmpty)
        #expect(Self.wordCount("u_time", in: Shaders.boardVertex) == 2)
        let clock: String = "float clock = mod(max(u_time, 0.0), MA_TIME_WRAP) * clamp(u_motion, 0.0, 1.0);"
        #expect(Shaders.boardVertex.contains(clock))
        let timeless: [String] = [Shaders.boardFragment, Shaders.glowVertex, Shaders.glowFragment]
        for source in timeless {
            #expect(Self.wordCount("u_time", in: source) == 0)
            #expect(Self.wordCount("u_motion", in: source) == 0)
        }
        // Every moving rate completes whole cycles in the wrap, so the wrap never jumps.
        let rates: [Double] = [Shaders.veinRate, Shaders.toxinRate, Shaders.sporeRate, Shaders.fuzzRate]
        for rate in rates {
            let cycles: Double = rate * Shaders.timeWrap
            #expect(abs(cycles - cycles.rounded()) < 1e-9, "\(rate)")
        }
    }

    @Test func atMostSixteenVec4UniformSlotsPerProgram() {
        #expect(Shaders.maxUniformVec4s == 16)
        var slotsByProgram: [String: Int] = [:]
        for program in Self.programs() {
            var slots: Int = 0
            for declaration in Self.declarations("uniform", in: "\(program.vertex)\n\(program.fragment)") {
                slots += declaration.type == "mat4" ? 4 : 1
                #expect(Shaders.uniformTypes[declaration.name] == declaration.type, "\(declaration.name)")
            }
            #expect(slots <= Shaders.maxUniformVec4s, "\(program.name) uses \(slots) vec4 slots")
            slotsByProgram[program.name] = slots
        }
        #expect(slotsByProgram == ["board": 7, "glow": 7])
        #expect(Shaders.uniformSlots == slotsByProgram)
    }

    @Test func noSamplerNoDiscardAndEveryLoopHasAConstantBound() {
        var loops: Int = 0
        for source in Self.sources() {
            #expect(!source.contains("sampler"))
            #expect(!source.contains("texture"))
            #expect(Self.wordCount("while", in: source) == 0)
            #expect(Self.wordCount("do", in: source) == 0)
            #expect(Self.wordCount("discard", in: source) == 0)
            #expect(Self.wordCount("break", in: source) == 0)
            for line in Self.lines(source) where Self.wordCount("for", in: line) > 0 {
                loops += 1
                // `for (int v = 0; v < N; v++) {` with N an integer literal of at most 64
                let parts: [String] = Self.tokens(line)
                #expect(parts.count == 10, "\(line)")
                guard parts.count == 10 else { continue }
                let variable: String = parts[2]
                #expect(parts[0] == "for" && parts[1] == "(int" && parts[3] == "=" && parts[4] == "0;", "\(line)")
                #expect(parts[5] == variable && parts[6] == "<", "\(line)")
                let bound: Int? = Int(parts[7].hasSuffix(";") ? String(parts[7].dropLast()) : "")
                #expect(bound != nil && (bound ?? 0) >= 1 && (bound ?? 0) <= 64, "\(line)")
                #expect(parts[8] == "\(variable)++)" && parts[9] == "{", "\(line)")
                #expect(Self.wordCount(variable, in: source) >= 4, "\(line)")
            }
            // GLSL ES 3.00 reserved words never used as names.
            let reserved: [String] = [
                "flat", "smooth", "centroid", "sample", "input", "output", "filter", "fixed", "half", "patch",
                "active", "common", "partition", "long", "short", "double", "unsigned", "superp", "inline", "static",
                "public", "external", "interface", "class", "union", "enum", "typedef", "template", "this", "goto",
                "resource", "cast", "namespace", "using", "sizeof", "noperspective", "volatile", "precise",
            ]
            for word in reserved { #expect(Self.wordCount(word, in: source) == 0, "\(word)") }
        }
        // The rock's copper octaves and the bloom's hyphae generations.
        #expect(loops == 2)
    }

    @Test func bracesBalancedAsciiAndInterfacesMatch() {
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
            #expect(braces == 0 && parens == 0 && !negative)
            var ascii: Bool = true
            for scalar in source.unicodeScalars where !scalar.isASCII { ascii = false }
            #expect(ascii)
        }
        for program in Self.programs() {
            let outputs: [String: String] = Self.interface("out", in: program.vertex)
            let inputs: [String: String] = Self.interface("in", in: program.fragment)
            #expect(outputs == inputs, "\(program.name)")
            let fragmentOutputs: [String: String] = Self.interface("out", in: program.fragment)
            #expect(fragmentOutputs == ["color": "vec4"])
        }
    }

    @Test func everyPaletteHexIsItsVec3ConstantMatchingTheCPUPalette() throws {
        #expect(Palette.all.count == 24)
        #expect(Shaders.paletteConstants.count == Palette.all.count)
        let tolerance: Double = 1.0 / 255.0
        for (index, entry) in Palette.all.enumerated() {
            let name: String = Shaders.constantName(entry.name)
            #expect(Shaders.paletteConstants[index].name == name)
            let hex: SIMD3<Double> = try #require(Self.hexColour(entry.hex), "\(entry.hex)")
            let cpu: SIMD3<Double> = SIMD3<Double>(entry.colour.x, entry.colour.y, entry.colour.z)
            #expect(Self.gap(hex, cpu) <= 1e-9, "\(entry.name): CPU colour differs from \(entry.hex)")
            let written: SIMD3<Double> = try #require(Self.vec3Constant(name, in: Shaders.boardVertex), "\(name)")
            #expect(Self.gap(written, hex) <= tolerance, "\(name)")
            #expect(Self.gap(written, cpu) <= 1e-6, "\(name)")
            // Every other source that declares the constant writes the same value.
            for source in Self.sources() {
                if let other = Self.vec3Constant(name, in: source) { #expect(Self.gap(other, written) <= 1e-9) }
            }
        }
        #expect(Shaders.constantName("capOpen") == "MA_CAP_OPEN")
        #expect(Shaders.constantName("veinCopper") == "MA_VEIN_COPPER")
        let broken: SIMD3<Double> = try #require(Self.vec3Constant("MA_BROKEN", in: Shaders.boardVertex))
        let expected: SIMD3<Double> = try #require(Self.hexColour("#FF6B5E"))
        #expect(Self.gap(broken, expected) <= tolerance)
        // Every palette constant a source uses is declared in that source.
        for source in Self.sources() {
            for entry in Shaders.paletteConstants where Self.wordCount(entry.name, in: source) > 0 {
                #expect(Self.vec3Constant(entry.name, in: source) != nil, "\(entry.name) used undeclared")
            }
        }
    }

    @Test func everyMaterialCodeIsSelectedAndDecoded() {
        #expect(Material.allCases.count == 24)
        #expect(Shaders.maxMaterial == 23)
        let expected: [String] = [
            "backdrop", "floor", "grid", "site", "toxin", "rock", "blocker", "nutrient", "nutrientConsumed", "vein",
            "bloom", "sprout", "root", "terminalClosed", "terminalOpen", "gaugePlate", "weightFill", "limitTick",
            "pipFilled", "pipHollow", "actionsLit", "actionsUnlit", "fuzz", "spore",
        ]
        for (index, material) in Material.allCases.enumerated() {
            #expect(material.rawValue == index)
            #expect("\(material)" == expected[index])
            #expect(material.code == Float(index))
            let literal: String = "isCode(m, \(index).0)"
            #expect(Shaders.boardFragment.contains(literal), "fragment does not decode \(material)")
            if material != .backdrop {
                let selection: String = "base = mix(base, \(material.paletteConstant), isCode(m, \(index).000000));"
                #expect(Shaders.boardVertex.contains(selection), "vertex does not select \(material)")
            }
            var known: Bool = false
            for entry in Palette.all where entry.name == material.paletteName { known = true }
            #expect(known, "\(material) selects an unknown colour")
        }
        #expect(Shaders.boardVertex.contains("base = mix(base, MA_BROKEN, broken);"))
    }

    @Test func theValueAndTheBrokenMarkTravelInUV() {
        #expect(Shaders.valueScale == 0.25)
        #expect(Shaders.brokenOffset == 0.5)
        let values: [Double] = [0, 0.1, 0.25, 0.5, 0.75, 1]
        for material in Material.allCases {
            for broken in [false, true] {
                for value in values {
                    let x: Double = Shaders.encode(material, value: value, broken: broken)
                    let decoded: (material: Material, value: Double, broken: Bool) = Shaders.decode(Double(Float(x)))
                    #expect(decoded.material == material, "\(material) \(value) \(broken)")
                    #expect(decoded.broken == broken, "\(material) \(value) \(broken)")
                    let want: Double = material.isValued ? value : 0
                    #expect(abs(decoded.value - want) < 1e-4, "\(material) \(value) \(broken)")
                }
            }
        }
        #expect(Shaders.encode(.vein, value: 2) == 9.25)
        #expect(Shaders.encode(.vein, value: Double.nan) == 9)
        #expect(Shaders.encode(.floor, value: 1, broken: true) == 1.5)
        #expect(Shaders.decode(Double.nan).material == .backdrop)
        #expect(Shaders.decode(-3).material == .backdrop)
        #expect(Shaders.decode(99).material == .spore)
    }

    @Test func backdropSporesCoverAtMostTwoPercent() {
        #expect(Shaders.backdropCoverage <= 0.02)
        #expect(Shaders.backdropCoverage > 0)
        #expect(Shaders.boardFragment.contains("vec3 gradient = mix(MA_CAVE, MA_CAVE_TOP, h);"))
    }

    @Test func glowGainIsCappedByTheLimit() {
        #expect(Shaders.glowGain(gain: 1, limit: 1.5) == 1)
        #expect(Shaders.glowGain(gain: 1.5, limit: 0.5) == 0.5)
        #expect(Shaders.glowGain(gain: 9, limit: 9) == Shaders.maxGlowGain)
        #expect(Shaders.glowGain(gain: Double.nan, limit: 1) == 0)
        #expect(Shaders.glowGain(gain: -1, limit: 1) == 0)
        let gain: String = "float gain = min(clamp(u_glowGain, 0.0, MA_MAX_GAIN), "
            + "clamp(u_glowLimit, 0.0, MA_MAX_GAIN));"
        #expect(Shaders.glowFragment.contains(gain))
        let length: Double = (Shaders.lightDirection * Shaders.lightDirection).sum().squareRoot()
        #expect(abs(length - 1) < 1e-12)
    }

    @Test func noRandomOrTimeOfDaySource() {
        let denied: [String] = ["rand(", "random", "noise(", "date", "Date", "timeOfDay", "gl_FragCoord", "iTime"]
        for source in Self.sources() {
            for word in denied { #expect(!source.contains(word), "\(word)") }
        }
        #expect(Self.wordCount("hash", in: Shaders.boardFragment) >= 4)
        #expect(Shaders.boardFragment.contains("return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);"))
    }

    @Test func sourceFileTextStaysWithinTheRules() throws {
        let tests: URL = URL(fileURLWithPath: #filePath)
        let core: URL = tests.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core").appendingPathComponent("Presentation")
            .appendingPathComponent("MyceliumArchitectShaders.swift")
        let text: String = try String(contentsOf: core, encoding: .utf8)
        let metal: String = "import " + "Metal" + "Kit"
        #expect(!text.contains(metal))
        let denied: [String] = ["Project" + "M", "Preset" + "Library", "Milk" + "Drop"]
        for word in denied { #expect(!text.contains(word), "\(word)") }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            #expect(line.count <= 120, "\(line)")
        }
        #expect(text.contains("T-R02G2203-004"))
    }

    /// A real front-end compile with `glslangValidator` when it is installed (macOS only; skipped otherwise).
    @Test func glslangValidatorAcceptsEverySourceWhenInstalled() throws {
        #if os(macOS)
        let candidates: [String] = ["/opt/homebrew/bin/glslangValidator", "/usr/local/bin/glslangValidator"]
        var tool: String? = nil
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) { tool = path }
        guard let validator = tool else { return }
        let directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ma-shaders-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files: [(name: String, source: String)] = [
            (name: "board.vert", source: Shaders.boardVertex), (name: "board.frag", source: Shaders.boardFragment),
            (name: "glow.vert", source: Shaders.glowVertex), (name: "glow.frag", source: Shaders.glowFragment),
        ]
        for file in files {
            let url: URL = directory.appendingPathComponent(file.name)
            try file.source.write(to: url, atomically: true, encoding: .utf8)
            let process: Process = Process()
            process.executableURL = URL(fileURLWithPath: validator)
            process.arguments = [url.path]
            let pipe: Pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let output: String = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            #expect(process.terminationStatus == 0, "\(file.name): \(output)")
        }
        #endif
    }

    /// The shaders' material table and the geometry's (`MyceliumArchitectMaterial`, feature 513 agent A) agree: the same
    /// cases with the same raw values, names and valued flags, so the stream the geometry writes is the one the shaders
    /// decode.
    @Test func theShaderAndGeometryMaterialTablesAgree() {
        #expect(MyceliumArchitectShaderMaterial.allCases.count == MyceliumArchitectMaterial.allCases.count)
        for material in MyceliumArchitectMaterial.allCases {
            let shader: MyceliumArchitectShaderMaterial? = MyceliumArchitectShaderMaterial(rawValue: material.rawValue)
            #expect(shader != nil, "code \(material.rawValue)")
            if let shader {
                #expect("\(shader)" == "\(material)", "name of code \(material.rawValue)")
                #expect(shader.isValued == material.isValued, "valued flag of code \(material.rawValue)")
            }
        }
    }
}
