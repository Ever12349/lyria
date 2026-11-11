import XCTest
import LyriaCore

final class ArtworkThumbnailTests: XCTestCase {
    func testBucketsCoverTheViewEdgeAndCapAt1024() {
        XCTAssertEqual(ArtworkThumbnails.neededPixels(edgePoints: 36, displayScale: 2), 72)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 36, displayScale: 2), 128)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 64, displayScale: 2), 128)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 64.1, displayScale: 2), 512)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 160, displayScale: 2), 512)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 512, displayScale: 2), 1024)
        XCTAssertEqual(ArtworkThumbnails.bucket(edgePoints: 600, displayScale: 2), 1024)
        XCTAssertEqual(ArtworkThumbnails.bucket(forNeededPixels: 0), 128)
        XCTAssertEqual(ArtworkThumbnails.bucket(forNeededPixels: 1024), 1024)
        XCTAssertEqual(ArtworkThumbnails.bucket(forNeededPixels: 5000), 1024)
        XCTAssertNil(ArtworkThumbnails.request(sourcePath: "/tmp/cover.jpg", edgePoints: 1, displayScale: 2))
        XCTAssertNil(ArtworkThumbnails.request(sourcePath: nil, edgePoints: 160, displayScale: 2))
        XCTAssertEqual(ArtworkThumbnails.jpegQuality, 0.85)
    }

    func testKeyChangesWhenPathBucketSizeOrMtimeChanges() {
        let base = ArtworkThumbKey(sourcePath: "/art/a.jpg", bucket: 128, fileSize: 10, modifiedMilliseconds: 20)
        XCTAssertNotEqual(base.token, ArtworkThumbKey(sourcePath: "/art/b.jpg", bucket: 128, fileSize: 10, modifiedMilliseconds: 20).token)
        XCTAssertNotEqual(base.token, ArtworkThumbKey(sourcePath: base.sourcePath, bucket: 512, fileSize: 10, modifiedMilliseconds: 20).token)
        XCTAssertNotEqual(base.token, ArtworkThumbKey(sourcePath: base.sourcePath, bucket: 128, fileSize: 11, modifiedMilliseconds: 20).token)
        XCTAssertNotEqual(base.token, ArtworkThumbKey(sourcePath: base.sourcePath, bucket: 128, fileSize: 10, modifiedMilliseconds: 21).token)
        XCTAssertNotEqual(
            ArtworkThumbnails.folderName(sourcePath: "/art/a.jpg"),
            ArtworkThumbnails.folderName(sourcePath: "/art/b.jpg")
        )
    }

    func testDiskReloadMtimeSizeAndInvalidationLeaveTheSourceAlone() async {
        let root = try? FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: FileManager.default.temporaryDirectory,
            create: true
        )
        guard let root else {
            XCTFail("temp directory")
            return
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.jpg")
        let original = Data("original-bytes".utf8)
        try? original.write(to: source)
        let decoder = CountingDecoder()
        let cache = ArtworkThumbnailCache(directory: root.appendingPathComponent("thumbs", isDirectory: true), decoder: decoder)

        async let first = cache.thumbnailJPEG(sourcePath: source.path, bucket: 128)
        async let second = cache.thumbnailJPEG(sourcePath: source.path, bucket: 128)
        let pair = await [first, second]
        XCTAssertEqual(pair[0], pair[1])
        XCTAssertEqual(decoder.calls, 1)
        let key = ArtworkThumbKey(
            sourcePath: source.path,
            bucket: 128,
            fileSize: ArtworkThumbnails.stamp(atPath: source.path)!.size,
            modifiedMilliseconds: ArtworkThumbnails.stamp(atPath: source.path)!.modifiedMilliseconds
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.diskURL(for: key).path))
        XCTAssertEqual(cache.memoryData(for: key), pair[0])

        let coldDecoder = CountingDecoder()
        let cold = ArtworkThumbnailCache(directory: cache.directory, decoder: coldDecoder)
        let reloaded = await cold.thumbnailJPEG(sourcePath: source.path, bucket: 128)
        XCTAssertEqual(reloaded, pair[0])
        XCTAssertEqual(coldDecoder.calls, 0)

        let stamped = ArtworkThumbnails.stamp(atPath: source.path)!
        try? FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
            ofItemAtPath: source.path
        )
        let afterMtime = await cache.thumbnailJPEG(sourcePath: source.path, bucket: 128)
        XCTAssertNotEqual(afterMtime, pair[0])
        XCTAssertEqual(decoder.calls, 2)
        XCTAssertNotEqual(
            ArtworkThumbnails.stamp(atPath: source.path)?.modifiedMilliseconds,
            stamped.modifiedMilliseconds
        )

        try? Data("original-bytes-plus".utf8).write(to: source)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
            ofItemAtPath: source.path
        )
        let grown = ArtworkThumbnails.stamp(atPath: source.path)!
        XCTAssertNotEqual(grown.size, stamped.size)
        let afterSize = await cache.thumbnailJPEG(sourcePath: source.path, bucket: 128)
        XCTAssertNotEqual(afterSize, afterMtime)
        XCTAssertEqual(decoder.calls, 3)

        let other = root.appendingPathComponent("other.jpg")
        try? Data("other-bytes".utf8).write(to: other)
        _ = await cache.thumbnailJPEG(sourcePath: other.path, bucket: 512)
        let otherStamp = ArtworkThumbnails.stamp(atPath: other.path)!
        let otherKey = ArtworkThumbKey(
            sourcePath: other.path,
            bucket: 512,
            fileSize: otherStamp.size,
            modifiedMilliseconds: otherStamp.modifiedMilliseconds
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.diskURL(for: otherKey).path))

        cache.invalidate(sourcePath: source.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.diskURL(for: key).deletingLastPathComponent().path))
        XCTAssertNil(cache.memoryData(for: key))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.diskURL(for: otherKey).path))
        XCTAssertEqual(try? Data(contentsOf: source), Data("original-bytes-plus".utf8))

        cache.invalidateAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.diskURL(for: otherKey).path))
        XCTAssertNil(cache.memoryData(for: otherKey))
        XCTAssertEqual(try? Data(contentsOf: source), Data("original-bytes-plus".utf8))
        XCTAssertEqual(try? Data(contentsOf: other), Data("other-bytes".utf8))
    }
}

#if canImport(ImageIO)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

extension ArtworkThumbnailTests {
    func testImageIORespectsBucketAndDoesNotUpscaleOrRewriteSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let largeURL = root.appendingPathComponent("large.jpg")
        let large = try Self.solidJPEG(width: 800, height: 600)
        try large.write(to: largeURL)
        let cache = ArtworkThumbnailCache(directory: root.appendingPathComponent("thumbs", isDirectory: true))
        let thumbData = await cache.thumbnailJPEG(sourcePath: largeURL.path, bucket: 128)
        let thumb = try XCTUnwrap(thumbData)
        let thumbSize = try Self.pixelSize(of: thumb)
        XCTAssertLessThanOrEqual(max(thumbSize.width, thumbSize.height), 128)
        XCTAssertGreaterThan(min(thumbSize.width, thumbSize.height), 0)
        XCTAssertEqual(try Data(contentsOf: largeURL), large)
        XCTAssertEqual(thumb.prefix(3), Data([0xFF, 0xD8, 0xFF]))

        let tinyURL = root.appendingPathComponent("tiny.jpg")
        let tiny = try Self.solidJPEG(width: 40, height: 30)
        try tiny.write(to: tinyURL)
        let smallData = await cache.thumbnailJPEG(sourcePath: tinyURL.path, bucket: 512)
        let small = try XCTUnwrap(smallData)
        let smallSize = try Self.pixelSize(of: small)
        XCTAssertLessThanOrEqual(max(smallSize.width, smallSize.height), 40)
        XCTAssertEqual(try Data(contentsOf: tinyURL), tiny)
    }

    private static func solidJPEG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestImageError()
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw TestImageError() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw TestImageError()
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw TestImageError() }
        return data as Data
    }

    private static func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            throw TestImageError()
        }
        return (width, height)
    }

    private struct TestImageError: Error {}
}
#endif

private final class CountingDecoder: ArtworkThumbDecoding, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls = 0

    func makeThumbnailJPEG(sourceURL: URL, maxPixelSize: Int) -> Data? {
        lock.lock()
        calls += 1
        let call = calls
        lock.unlock()
        Thread.sleep(forTimeInterval: 0.05)
        var data = Data("thumb-\(call)-\(maxPixelSize)-".utf8)
        data.append(contentsOf: sourceURL.path.utf8.prefix(8))
        return data
    }
}
