// TokenizerTests — feature 159 (A22-P01) T-A22-109 (SC-A22-103; FR-A22-105; clarification Q4). Host-free and short:
// - tokens rebuild every line exactly, with contiguous UTF-8 ranges, on varied samples (including non-ASCII text);
// - every `TokenKind` is classified at least once by one sample;
// - lines split on `\n`, `\r\n` and `\r`, a final line with no newline, and the trailing-newline rule;
// - block comments continue across lines and an unclosed one runs to the end of the source;
// - number forms `1`, `1.0`, `.5`, `1e-3`, `2u`, `0x1F`;
// - a 16,384-byte single line (the source limit) is tokenized in one pass; its counts are checked, never its time.
import Testing
import ShaderStudioCore

@Suite struct TokenizerTests {
    /// Varied sources: a full shader, operators, comments, CRLF, unicode in comments and code, odd characters.
    private static let samples: [String] = [
        "",
        "\n",
        "#version 300 es\nprecision highp float;\nout vec4 fragColor;\nvoid main() { fragColor = vec4(1.0); }\n",
        "  #define SCALE 2.0 // twice\nfloat f(float x) { return x * SCALE; }",
        "a<<=1;b>>=2;c++;d--;e&&f||g^^h;i!=j;k==l;m<=n;o>=p;q?r:s;~t;u%=v;",
        "/* one\n two */ float x = 1.0; /* three */ int y = 0x1F; // done\r\nuint z = 2u;\r",
        "// héllo wörld ✓\nfloat café = 1.0; // ünïcode\n\"str\" 'c' @ $ \\ `",
        "vec2 uv = gl_FragCoord.xy / u_resolution;\tcolor = mix(a, b, smoothstep(0.0, 1.0, uv.x));",
        "/* never closed\nstill comment\n",
        "x = .5 + 1e-3 + 1.5E+2 + 3.f + 7U;",
    ]

    private static func kinds(_ line: [Token]) -> [TokenKind] { line.map(\.kind) }

    @Test func tokensRebuildEveryLineExactly() {
        for sample in Self.samples {
            let lines = GLSLTokenizer.lines(of: sample)
            let tokens = GLSLTokenizer.tokenize(sample)
            #expect(tokens.count == lines.count, "line count of \(sample.debugDescription)")
            for (line, lineTokens) in zip(lines, tokens) {
                #expect(lineTokens.map(\.text).joined() == line, "rebuild of \(line.debugDescription)")
                var offset = 0
                for token in lineTokens {
                    #expect(token.range.lowerBound == offset)
                    #expect(token.range.count == token.text.utf8.count)
                    #expect(!token.text.isEmpty)
                    offset = token.range.upperBound
                }
                #expect(offset == line.utf8.count)
            }
        }
    }

    @Test func everyKindIsClassified() {
        let source = """
        #define N 4
        /* block */ uniform float u_speed; // line
        void main() { float t = sin(gl_FragCoord.x) * 2.0 + u_speed; }
        """
        let seen = Set(GLSLTokenizer.tokenize(source).flatMap { $0.map(\.kind) })
        #expect(seen == Set(TokenKind.allCases))
        let flat = GLSLTokenizer.tokenize(source).flatMap { $0 }
        func kind(of text: String) -> TokenKind? { flat.first { $0.text == text }?.kind }
        #expect(kind(of: "#define N 4") == .preprocessor)
        #expect(kind(of: "/* block */") == .comment)
        #expect(kind(of: "// line") == .comment)
        #expect(kind(of: "uniform") == .keyword)
        #expect(kind(of: "float") == .type)
        #expect(kind(of: "void") == .type)
        #expect(kind(of: "sin") == .builtinFunction)
        #expect(kind(of: "gl_FragCoord") == .builtinVariable)
        #expect(kind(of: "u_speed") == .identifier)
        #expect(kind(of: "2.0") == .number)
        #expect(kind(of: "*") == .operatorSymbol)
        #expect(kind(of: "=") == .operatorSymbol)
        #expect(kind(of: "(") == .punctuation)
        #expect(kind(of: ".") == .punctuation)
        #expect(kind(of: ";") == .punctuation)
        #expect(kind(of: " ") == .whitespace)
    }

    @Test func lineEndingsAndFinalLine() {
        let plain = GLSLTokenizer.lines(of: "a\nb\nc")
        #expect(plain == ["a", "b", "c"])
        #expect(GLSLTokenizer.lines(of: "a\r\nb\r\nc") == plain)
        #expect(GLSLTokenizer.lines(of: "a\rb\rc") == plain)
        #expect(GLSLTokenizer.lines(of: "a\r\nb\rc") == plain)
        // Every terminator starts a line (as an editor shows it): a trailing newline gives a final empty line.
        #expect(GLSLTokenizer.lines(of: "a\nb\nc\n") == ["a", "b", "c", ""])
        #expect(GLSLTokenizer.lines(of: "a\r\nb\r\nc\r\n") == ["a", "b", "c", ""])
        #expect(GLSLTokenizer.lines(of: "") == [""])
        #expect(GLSLTokenizer.lines(of: "\n\n") == ["", "", ""])
        // `\r\n` is one terminator, `\n\r` is two.
        #expect(GLSLTokenizer.lines(of: "a\n\rb") == ["a", "", "b"])
        // Tokens never contain a terminator.
        let tokens = GLSLTokenizer.tokenize("float a;\r\nfloat b;\rfloat c;")
        #expect(tokens.count == 3)
        #expect(tokens.allSatisfy { $0.allSatisfy { !$0.text.contains("\r") && !$0.text.contains("\n") } })
    }

    @Test func blockCommentContinuesAcrossLines() {
        let tokens = GLSLTokenizer.tokenize("float a; /* start\nmiddle line\nend */ float b;\n#define X")
        #expect(tokens.count == 4)
        #expect(tokens[0].last == Token(kind: .comment, text: "/* start", range: 9..<17))
        #expect(Self.kinds(tokens[1]) == [.comment])
        #expect(tokens[1][0].text == "middle line")
        #expect(tokens[2][0] == Token(kind: .comment, text: "end */", range: 0..<6))
        #expect(Self.kinds(tokens[2]).dropFirst() == [.whitespace, .type, .whitespace, .identifier, .punctuation])
        #expect(Self.kinds(tokens[3]) == [.preprocessor])
        // A line that starts inside a comment is not a directive even if the comment's text begins with `#`.
        let hashInside = GLSLTokenizer.tokenize("/*\n#not a directive */ x")
        #expect(hashInside[1][0] == Token(kind: .comment, text: "#not a directive */", range: 0..<19))
    }

    @Test func unclosedBlockCommentRunsToTheEnd() {
        let source = "float a;\n/* open\nvoid main() { }\n\n*/ x"
        let tokens = GLSLTokenizer.tokenize("float a;\n/* open\nvoid main() { }\n")
        #expect(tokens.count == 4)
        #expect(Self.kinds(tokens[1]) == [.comment])
        #expect(Self.kinds(tokens[2]) == [.comment])
        #expect(tokens[3].isEmpty)
        let closedLate = GLSLTokenizer.tokenize(source)
        #expect(Self.kinds(closedLate[4]) == [.comment, .whitespace, .identifier])
        // A lone `/*` at the very end, and `/*/` (not closed by its own `*`).
        #expect(Self.kinds(GLSLTokenizer.tokenize("x /*")[0]) == [.identifier, .whitespace, .comment])
        #expect(Self.kinds(GLSLTokenizer.tokenize("/*/ y")[0]) == [.comment])
    }

    @Test func numberForms() {
        for literal in ["1", "1.0", ".5", "1e-3", "2u", "0x1F", "1.", "1.5E+2", "3.0f", "7U", "0XffU", "10"] {
            let tokens = GLSLTokenizer.tokens(of: literal)
            #expect(tokens == [Token(kind: .number, text: literal, range: 0..<literal.utf8.count)], "\(literal)")
        }
        // An `e` without digits is not an exponent; `u` does not follow a float; `x.y` swizzles stay punctuation.
        #expect(Self.kinds(GLSLTokenizer.tokens(of: "1e")) == [.number, .identifier])
        #expect(Self.kinds(GLSLTokenizer.tokens(of: "1.0u")) == [.number, .identifier])
        #expect(Self.kinds(GLSLTokenizer.tokens(of: "v.x")) == [.identifier, .punctuation, .identifier])
        #expect(GLSLTokenizer.tokens(of: "a-1").map(\.text) == ["a", "-", "1"])
    }

    @Test func operatorsAreLongestMatch() {
        let texts = GLSLTokenizer.tokens(of: "a<<=b>>c<=d").map(\.text)
        #expect(texts == ["a", "<<=", "b", ">>", "c", "<=", "d"])
        #expect(Self.kinds(GLSLTokenizer.tokens(of: "x+++y")) == [.identifier, .operatorSymbol, .operatorSymbol,
                                                                     .identifier])
    }

    @Test func longSingleLineIsTokenizedInOnePass() {
        // 16,384 bytes on one line: 2,048 repetitions of the 8-byte "a+1.0*b;" fragment.
        let fragment = "a+1.0*b;"
        let line = String(repeating: fragment, count: 2_048)
        #expect(line.utf8.count == 16_384)
        let tokens = GLSLTokenizer.tokenize(line)
        #expect(tokens.count == 1)
        #expect(tokens[0].count == 2_048 * 6)
        #expect(tokens[0].filter { $0.kind == .number }.count == 2_048)
        #expect(tokens[0].last?.range.upperBound == 16_384)
        // One unclosed comment over the whole limit is a single token.
        let comment = "/*" + String(repeating: "x", count: 16_382)
        #expect(GLSLTokenizer.tokenize(comment) == [[Token(kind: .comment, text: comment, range: 0..<16_384)]])
    }

    @Test func wordSetsAreDisjoint() {
        let sets = [GLSLTokenizer.keywords, GLSLTokenizer.types, GLSLTokenizer.builtinFunctions,
                    GLSLTokenizer.builtinVariables]
        for i in sets.indices {
            for j in sets.indices where i < j { #expect(sets[i].isDisjoint(with: sets[j])) }
        }
        #expect(GLSLTokenizer.types.isSuperset(of: ["float", "vec2", "vec3", "vec4", "mat4", "sampler2D", "bool",
                                                    "int", "uint", "void"]))
        #expect(GLSLTokenizer.builtinFunctions.isSuperset(of: ["sin", "mix", "smoothstep", "texture", "fract"]))
        #expect(GLSLTokenizer.builtinVariables.contains("gl_FragCoord"))
    }
}
