// ChainDocumentTests — feature 180 (A25-P01) T-A25-109 (FR-A25-106; SC-A25-105; clarification Q3). Chains (empty,
// full-length with every effect, disabled nodes, values at range ends, a fractional value) round-trip equal and
// byte-identical; the envelope has sorted keys, the kind and version 1; one crafted file per refusal code on reading:
// damaged (not JSON, an array, the wrong kind, no body, no nodes, a mistyped field, an extra key), newer-version,
// too-large, not-finite (the file carries "NaN" as a string, since JSON has no NaN token), out-of-range (a value and a
// node identifier), unknown-effect, unknown-parameter, missing-parameter, too-many-nodes and duplicate-node.
// Synthetic data only.
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerCore

@Suite struct ChainDocumentTests {
    /// Sample chains to round-trip.
    private static func chains() -> [EffectChain] {
        var full = EffectChain(nodes: (0..<ChainLimits.maxNodes).map {
            EffectNode(id: 100 + $0, effect: EffectID.allCases[$0 % 5], enabled: $0 % 3 != 0)
        })
        full.nodes[0].values["exposure"] = -2
        full.nodes[2].values["amplitude"] = 0.05
        full.nodes[3].values["softness"] = 0.123456789
        full.nodes[4].values["levels"] = 32
        let single = EffectChain(nodes: [EffectNode(id: ChainLimits.maxNodeID, effect: .distort)])
        return [.empty, full, single]
    }

    @Test func roundTripIsEqualAndByteIdentical() throws {
        for chain in Self.chains() {
            let data = ChainDocument.encode(chain)
            #expect(ChainDocument.encode(chain) == data)
            let decoded = try ChainDocument.decode(data).get()
            #expect(decoded == chain)
            #expect(decoded.fingerprint() == chain.fingerprint())
            #expect(ChainDocument.encode(decoded) == data)
        }
    }

    @Test func envelopeShape() throws {
        let chain = EffectChain(nodes: [EffectNode(id: 1, effect: .blur)])
        let text = String(decoding: ChainDocument.encode(chain), as: UTF8.self)
        #expect(text == #"{"body":{"nodes":[{"effect":"blur","enabled":true,"id":1,"values":{"radius":2}}]},"#
                + #""kind":"a25.effect-chain","version":1}"#)
        #expect(String(decoding: ChainDocument.encode(.empty), as: UTF8.self)
                == #"{"body":{"nodes":[]},"kind":"a25.effect-chain","version":1}"#)
    }

    /// A file of the given nodes' JSON, kind and version.
    private func file(nodes: String, kind: String = "a25.effect-chain", version: String = "1") -> Data {
        Data(#"{"body":{"nodes":[\#(nodes)]},"kind":"\#(kind)","version":\#(version)}"#.utf8)
    }

    /// A node's JSON.
    private func node(id: String = "1", effect: String = "blur", enabled: String = "true",
                      values: String = #""radius":2"#) -> String {
        #"{"effect":"\#(effect)","enabled":\#(enabled),"id":\#(id),"values":{\#(values)}}"#
    }

    /// The refusal of `data`, or nil when it decodes.
    private func refusal(_ data: Data) -> ChainRefusal? {
        if case let .failure(refusal) = ChainDocument.decode(data) { return refusal }
        return nil
    }

    @Test func craftedFileIsValid() {
        #expect(ChainDocument.decode(file(nodes: node())) == .success(EffectChain(nodes: [EffectNode(id: 1, effect: .blur)])))
    }

    @Test func damagedFilesAreRefused() {
        let damaged: [Data] = [
            Data("not json".utf8),
            Data("[1,2]".utf8),
            file(nodes: node(), kind: "a24.benchmark-run"),
            file(nodes: node(), version: "0"),
            file(nodes: node(), version: "\"1\""),
            file(nodes: node(), version: "true"),
            Data(#"{"kind":"a25.effect-chain","version":1}"#.utf8),
            Data(#"{"body":{},"kind":"a25.effect-chain","version":1}"#.utf8),
            Data(#"{"body":{"nodes":{}},"kind":"a25.effect-chain","version":1}"#.utf8),
            file(nodes: node(id: "1.5")),
            file(nodes: node(id: "true")),
            file(nodes: node(enabled: "1")),
            file(nodes: node(values: #""radius":"two""#)),
            file(nodes: node(values: #""radius":true"#)),
            file(nodes: #"{"effect":"blur","enabled":true,"id":1,"values":{"radius":2},"extra":0}"#),
            file(nodes: #"{"effect":"blur","enabled":true,"values":{"radius":2}}"#),
            file(nodes: "1"),
        ]
        for data in damaged {
            #expect(refusal(data) == .damaged, "\(String(decoding: data, as: UTF8.self))")
        }
    }

    @Test func everyRefusalCodeFromACraftedFile() {
        #expect(refusal(file(nodes: node(), version: "2")) == .newerVersion)
        var large = file(nodes: node())
        large.append(Data(repeating: 0x20, count: ChainLimits.maxFileBytes + 1 - large.count))
        #expect(large.count == ChainLimits.maxFileBytes + 1)
        #expect(refusal(large) == .tooLarge)
        var atCap = file(nodes: node())
        atCap.append(Data(repeating: 0x20, count: ChainLimits.maxFileBytes - atCap.count))
        #expect(refusal(atCap) == nil)
        #expect(refusal(file(nodes: node(values: #""radius":"NaN""#))) == .notFinite("blur.radius"))
        #expect(refusal(file(nodes: node(values: #""radius":"Infinity""#))) == .notFinite("blur.radius"))
        #expect(refusal(file(nodes: node(values: #""radius":9"#))) == .outOfRange("blur.radius"))
        #expect(refusal(file(nodes: node(values: #""radius":2.5"#))) == .outOfRange("blur.radius"))
        #expect(refusal(file(nodes: node(id: "65536"))) == .outOfRange("node.id"))
        #expect(refusal(file(nodes: node(effect: "sharpen"))) == .unknownEffect("sharpen"))
        #expect(refusal(file(nodes: node(values: #""radius":2,"sigma":1"#))) == .unknownParameter("blur.sigma"))
        #expect(refusal(file(nodes: node(values: ""))) == .missingParameter("blur.radius"))
        let nine = (1...9).map { node(id: "\($0)") }.joined(separator: ",")
        #expect(refusal(file(nodes: nine)) == .tooManyNodes)
        #expect(refusal(file(nodes: node(id: "3") + "," + node(id: "3"))) == .duplicateNode(3))
        let codes = [
            refusal(Data("x".utf8)), refusal(file(nodes: node(), version: "2")), refusal(large),
            refusal(file(nodes: node(values: #""radius":"NaN""#))), refusal(file(nodes: node(values: #""radius":9"#))),
            refusal(file(nodes: node(effect: "sharpen"))), refusal(file(nodes: node(values: #""radius":2,"sigma":1"#))),
            refusal(file(nodes: node(values: ""))), refusal(file(nodes: nine)),
            refusal(file(nodes: node(id: "3") + "," + node(id: "3"))),
        ].compactMap { $0?.code }
        #expect(codes == ["damaged", "newer-version", "too-large", "not-finite", "out-of-range", "unknown-effect",
                          "unknown-parameter", "missing-parameter", "too-many-nodes", "duplicate-node"])
    }

    @Test func nonFiniteChainEncodesAndIsRefusedOnReading() {
        var node = EffectNode(id: 1, effect: .grade)
        node.values["exposure"] = -.infinity
        let data = ChainDocument.encode(EffectChain(nodes: [node]))
        #expect(String(decoding: data, as: UTF8.self).contains(#""exposure":"-Infinity""#))
        #expect(refusal(data) == .notFinite("grade.exposure"))
    }
}
