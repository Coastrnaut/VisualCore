// ImageImportTests — feature 183 (A25-P04) T-A25-405 (clarification Q3; SC-A25-401 – SC-A25-403). `ImageImport.decode`
// on pictures made by `ImportFixtures`: the eight EXIF orientations put the marked corner top left at the right size;
// Display P3 red decodes within 3/255 of CoreGraphics' sRGB conversion; 4,000 × 1,000 decodes to 2,048 × 512 and a
// small picture is not enlarged; damaged, tiny and oversized data are refused with their codes; partial alpha is kept
// straight. Each test is short (no sleep, no clock).
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
@testable import EffectsComposerExperience

/// The import decoder of clarification Q2.
@Suite("ImageImport")
struct ImageImportTests {
    /// The decoded picture, or a recorded failure.
    private func decoded(_ data: Data, limit: Int = ImageImport.maximumEdge) -> ImportedPicture? {
        switch ImageImport.decode(data, limit: limit) {
        case .success(let picture): return picture
        case .failure(let refusal):
            Issue.record("refused: \(refusal.code)")
            return nil
        }
    }

    /// The refusal for `data`, or nil when it decoded.
    private func refusal(_ data: Data, limit: Int = ImageImport.maximumEdge) -> ImportRefusal? {
        if case .failure(let refusal) = ImageImport.decode(data, limit: limit) { return refusal }
        return nil
    }

    /// Whether the pixel is red (lenient for edge filtering).
    private func isRed(_ p: SIMD4<UInt8>) -> Bool { p.x > 200 && p.z < 60 }

    @Test("Each EXIF orientation puts the marked corner top left with the right size", arguments: 1...8)
    func orientation(_ orientation: Int) throws {
        let picture = try #require(decoded(ImportFixtures.oriented(orientation)))
        let swapped = orientation >= 5
        #expect(picture.width == (swapped ? 48 : 64))
        #expect(picture.height == (swapped ? 64 : 48))
        let w = picture.width, h = picture.height
        #expect(isRed(picture.pixel(x: 2, y: 2)), "top left not red for orientation \(orientation)")
        #expect(!isRed(picture.pixel(x: w - 3, y: 2)))
        #expect(!isRed(picture.pixel(x: 2, y: h - 3)))
        #expect(!isRed(picture.pixel(x: w - 3, y: h - 3)))
        #expect(picture.pixel(x: 2, y: 2).w == 255)
    }

    @Test("Display P3 red decodes within 3/255 of the sRGB conversion")
    func displayP3() throws {
        let p3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let picture = try #require(decoded(ImportFixtures.flat(width: 16, height: 16, red: 255, green: 0, blue: 0,
                                                              space: p3)))
        let expected = ImportFixtures.srgbReference(of: (255, 0, 0), in: p3)
        let p = picture.pixel(x: 8, y: 8)
        #expect(p.x == 255)
        #expect(abs(Int(p.x) - expected.x) <= 3)
        #expect(abs(Int(p.y) - expected.y) <= 3)
        #expect(abs(Int(p.z) - expected.z) <= 3)
        #expect(p.w == 255)
    }

    @Test("4,000 × 1,000 decodes to 2,048 × 512; a small picture keeps its size")
    func downsize() throws {
        let big = try #require(decoded(ImportFixtures.flat(width: 4_000, height: 1_000, red: 10, green: 200, blue: 30)))
        #expect(big.width == 2_048)
        #expect(big.height == 512)
        let small = try #require(decoded(ImportFixtures.flat(width: 20, height: 12, red: 1, green: 2, blue: 3)))
        #expect(small.width == 20)
        #expect(small.height == 12)
        let limited = try #require(decoded(ImportFixtures.flat(width: 300, height: 100, red: 1, green: 2, blue: 3),
                                           limit: ImageImport.limit(maxTextureSize: 150)))
        #expect(limited.width == 150)
        #expect(limited.height == 50)
        #expect(ImageImport.limit(maxTextureSize: 16_384) == 2_048)
        #expect(ImageImport.limit(maxTextureSize: 1_024) == 1_024)
    }

    @Test("Damaged data is refused as a25.image-damaged")
    func damaged() {
        var generator = SystemRandomNumberGenerator()
        let noise = Data((0..<4_096).map { _ in UInt8.random(in: 0...255, using: &generator) })
        #expect(refusal(noise) == .imageDamaged)
        let png = ImportFixtures.flat(width: 64, height: 64, red: 9, green: 9, blue: 9)
        // A PNG cut after its header (signature and IHDR, 33 bytes) has no image data ImageIO can read. ImageIO
        // decodes a PNG cut in the middle of its compressed data without error, so the cut is made before it.
        #expect(refusal(png.prefix(33)) == .imageDamaged)
        #expect(refusal(png.prefix(8)) == .imageDamaged)
        #expect(refusal(Data()) == .imageDamaged)
        #expect(ImportRefusal.imageDamaged.code == "a25.image-damaged")
        #expect(ImportRefusal.imageDamaged.message == "This picture cannot be read.")
    }

    @Test("A PNG cut in its image data decodes at its stated size or is refused, never anything else")
    func truncatedInData() {
        // As built (T-A25-412): ImageIO decodes a PNG cut in the middle of its compressed data, the missing rows
        // coming back blank, so such a cut is not always refused. Whatever ImageIO does, the import yields either a
        // picture of the stated size or the damaged refusal.
        let png = ImportFixtures.flat(width: 64, height: 64, red: 9, green: 9, blue: 9)
        for cut in [png.count / 2, png.count - 12] {
            switch ImageImport.decode(png.prefix(cut), limit: 2_048) {
            case .success(let picture):
                #expect(picture.width == 64 && picture.height == 64)
                #expect(picture.bytes.count == 64 * 64 * 4)
            case .failure(let refusal):
                #expect(refusal == .imageDamaged)
            }
        }
    }

    @Test("A 4 × 4 picture is refused as a25.image-too-small")
    func tooSmall() {
        #expect(refusal(ImportFixtures.flat(width: 4, height: 4, red: 1, green: 1, blue: 1)) == .imageTooSmall)
        #expect(refusal(ImportFixtures.flat(width: 64, height: 7, red: 1, green: 1, blue: 1)) == .imageTooSmall)
        #expect(ImportRefusal.imageTooSmall.code == "a25.image-too-small")
        #expect(ImportRefusal.imageTooSmall.message == "This picture is too small.")
    }

    @Test("Data above 50 MiB is refused as a25.image-too-large before decoding")
    func tooLarge() {
        #expect(ImageImport.maxDataBytes == 52_428_800)
        #expect(refusal(Data(count: ImageImport.maxDataBytes + 1)) == .imageTooLarge)
        #expect(ImportRefusal.imageTooLarge.code == "a25.image-too-large")
        #expect(ImportRefusal.imageTooLarge.message == "This picture is too large.")
    }

    @Test("Partial alpha is kept as straight alpha")
    func partialAlpha() throws {
        let picture = try #require(decoded(ImportFixtures.flat(width: 16, height: 16, red: 200, green: 100, blue: 50,
                                                              alpha: 128)))
        let p = picture.pixel(x: 8, y: 8)
        #expect(abs(Int(p.w) - 128) <= 2)
        #expect(abs(Int(p.x) - 200) <= 2)
        #expect(abs(Int(p.y) - 100) <= 2)
        #expect(abs(Int(p.z) - 50) <= 2)
    }
}
