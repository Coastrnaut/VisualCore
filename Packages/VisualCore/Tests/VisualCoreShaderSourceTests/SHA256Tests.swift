// SHA256Tests — feature 004 T-F302: FIPS 180-4 / NIST CAVP example vectors.
import Testing
@testable import VisualCoreShaderSource

@Test func emptyString() {
    #expect(SHA256.hex(of: Array("".utf8)) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
}

@Test func abc() {
    #expect(SHA256.hex(of: Array("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@Test func twoBlockMessage() {
    let m = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    #expect(SHA256.hex(of: Array(m.utf8)) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
}

@Test func oneMillionA() {
    #expect(SHA256.hex(of: [UInt8](repeating: 0x61, count: 1_000_000)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
}
