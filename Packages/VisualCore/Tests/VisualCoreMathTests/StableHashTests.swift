// StableHashTests — feature 188 T-U02-002: FIPS 180-4 example vectors for the public SHA-256 of VisualCoreMath.
import Testing
import VisualCoreMath

@Suite struct StableHashTests {
    @Test func fipsVectors() {
        #expect(StableHash.sha256Hex([]) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(StableHash.sha256Hex(Array("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let twoBlocks = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(StableHash.sha256Hex(Array(twoBlocks.utf8)) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        #expect(StableHash.sha256Hex([UInt8](repeating: 0x61, count: 1_000_000))
                == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test func formOfTheResults() {
        let bytes = StableHash.sha256(Array("abc".utf8))
        #expect(bytes.count == 32)
        #expect(bytes.first == 0xba && bytes.last == 0xad)
        let hex = StableHash.sha256Hex(Array("abc".utf8))
        #expect(hex.count == 64)
        #expect(hex.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) })
    }
}
