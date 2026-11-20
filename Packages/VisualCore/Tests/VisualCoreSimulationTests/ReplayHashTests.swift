// ReplayHashTests — feature 214 R02-F14 T-R02F14-002 (FR-R02F14-005; clarification Q4; research R3).
// The expected values are rebuilt here byte by byte with FIPS 180-4 SHA-256 (`StableHash.sha256`).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func le(_ value: UInt64) -> [UInt8] { (0..<8).map { UInt8(truncatingIfNeeded: value >> (UInt64($0) * 8)) } }

private let checksums: [UInt64] = [0x0123_4567_89ab_cdef, 42, 0xffff_ffff_ffff_ffff, 7]

@Test func replayHashKnownAnswerForThreeSteps() throws {
    var expected = StableHash.sha256(Array("vc.replay.v1".utf8) + le(checksums[0]))
    var hash = ReplayHash.start(checksum: checksums[0])
    #expect(hash.bytes == expected)
    for n in 1...3 {
        expected = StableHash.sha256(expected + le(UInt64(n)) + le(checksums[n]))
        hash = hash.next(step: n, checksum: checksums[n])
        #expect(hash.bytes == expected)
    }
    #expect(hash.bytes.count == 32)
    #expect(hash.hex == "038fb17326273f70a47ba6838628c22c546e0c35c7ee31b4367e22c5dc375cc3") // cross-checked with Python hashlib
}

@Test func replayHashChainsAndReactsToOneChecksum() {
    var base = ReplayHash.start(checksum: 1)
    var hashes = [base]
    for n in 1...20 { base = base.next(step: n, checksum: UInt64(n) &* 31); hashes.append(base) }
    #expect(Set(hashes).count == 21)
    for changed in 0...20 {
        var other = ReplayHash.start(checksum: changed == 0 ? 2 : 1)
        for n in 1...20 { other = other.next(step: n, checksum: UInt64(n) &* 31 &+ (n == changed ? 1 : 0)) }
        #expect(other != base)
    }
    #expect(ReplayHash.start(checksum: 5).next(step: 1, checksum: 9) != ReplayHash.start(checksum: 5).next(step: 2, checksum: 9))
}

@Test func replayHashHexAndCodable() throws {
    let hash = ReplayHash.start(checksum: 99)
    #expect(hash.hex.count == 64)
    #expect(hash.hex == StableHash.sha256Hex(Array("vc.replay.v1".utf8) + le(99)))
    #expect(ReplayHash(hex: hash.hex) == hash)
    #expect(ReplayHash(hex: hash.hex.uppercased()) == hash)
    for bad in ["", String(hash.hex.dropLast()), hash.hex + "0", String(hash.hex.dropLast()) + "g"] {
        #expect(ReplayHash(hex: bad) == nil)
    }
    let data = try JSONEncoder().encode([hash])
    #expect(String(decoding: data, as: UTF8.self) == "[\"\(hash.hex)\"]")
    #expect(try JSONDecoder().decode([ReplayHash].self, from: data) == [hash])
    #expect(throws: DecodingError.self) { try JSONDecoder().decode([ReplayHash].self, from: Data(#"["zz"]"#.utf8)) }
}
