import Foundation

#if canImport(ImageIO)
import CoreGraphics
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#endif

/// Display-size cover buckets. Originals stay where the scanner wrote them.
public enum ArtworkThumbnails {
    public static let pixelBuckets = [128, 512, 1024]
    public static let jpegQuality = 0.85

    /// `ceil(edge * scale)`, with exact integer results left alone.
    public static func neededPixels(edgePoints: Double, displayScale: Double) -> Int {
        let scaled = edgePoints * displayScale
        guard scaled > 0 else { return 0 }
        let nearest = scaled.rounded(.toNearestOrAwayFromZero)
        if abs(scaled - nearest) < 0.001 {
            return Int(nearest)
        }
        return Int(ceil(scaled))
    }

    /// Smallest bucket that covers `pixels`. Above 1024, stay at 1024.
    public static func bucket(forNeededPixels pixels: Int) -> Int {
        let needed = max(pixels, 0)
        for size in pixelBuckets where size >= needed {
            return size
        }
        return pixelBuckets[pixelBuckets.count - 1]
    }

    public static func bucket(edgePoints: Double, displayScale: Double) -> Int {
        bucket(forNeededPixels: neededPixels(edgePoints: edgePoints, displayScale: displayScale))
    }

    public static func stamp(atPath path: String) -> ArtworkFileStamp? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              let date = attributes[.modificationDate] as? Date
        else { return nil }
        return ArtworkFileStamp(
            size: size.int64Value,
            modifiedMilliseconds: milliseconds(date)
        )
    }

    /// Nil while the view has no usable edge, no path, or the source file is missing.
    public static func request(sourcePath: String?, edgePoints: Double, displayScale: Double) -> ArtworkThumbRequest? {
        guard let sourcePath, !sourcePath.isEmpty, edgePoints > 1 else { return nil }
        guard let stamp = stamp(atPath: sourcePath) else { return nil }
        let key = ArtworkThumbKey(
            sourcePath: sourcePath,
            bucket: bucket(edgePoints: edgePoints, displayScale: displayScale),
            fileSize: stamp.size,
            modifiedMilliseconds: stamp.modifiedMilliseconds
        )
        return ArtworkThumbRequest(key: key)
    }

    public static func folderName(sourcePath: String) -> String {
        SHA256.hash(Data(sourcePath.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

public struct ArtworkFileStamp: Equatable, Sendable {
    public var size: Int64
    public var modifiedMilliseconds: Int64

    public init(size: Int64, modifiedMilliseconds: Int64) {
        self.size = size
        self.modifiedMilliseconds = modifiedMilliseconds
    }
}

public struct ArtworkThumbKey: Hashable, Sendable {
    public var sourcePath: String
    public var bucket: Int
    public var fileSize: Int64
    public var modifiedMilliseconds: Int64

    public init(sourcePath: String, bucket: Int, fileSize: Int64, modifiedMilliseconds: Int64) {
        self.sourcePath = sourcePath
        self.bucket = bucket
        self.fileSize = fileSize
        self.modifiedMilliseconds = modifiedMilliseconds
    }

    public var token: String {
        "\(bucket)#\(fileSize)#\(modifiedMilliseconds)#\(sourcePath)"
    }
}

public struct ArtworkThumbRequest: Equatable, Sendable {
    public var key: ArtworkThumbKey

    public init(key: ArtworkThumbKey) {
        self.key = key
    }
}

public protocol ArtworkThumbDecoding: Sendable {
    /// JPEG bytes at or below `maxPixelSize` on the long edge. Must not write the source file.
    func makeThumbnailJPEG(sourceURL: URL, maxPixelSize: Int) -> Data?
}

public struct ImageIOArtworkDecoder: ArtworkThumbDecoding {
    public init() {}

    public func makeThumbnailJPEG(sourceURL: URL, maxPixelSize: Int) -> Data? {
        #if canImport(ImageIO)
        ImageIOThumbnail.jpeg(
            sourceURL: sourceURL,
            maxPixelSize: maxPixelSize,
            quality: ArtworkThumbnails.jpegQuality
        )
        #else
        _ = (sourceURL, maxPixelSize)
        return nil
        #endif
    }
}

/// Memory plus disk thumbnails for one cache directory. Safe to share across loads.
public final class ArtworkThumbnailCache: @unchecked Sendable {
    public let directory: URL
    private let decoder: any ArtworkThumbDecoding
    private let memory = NSCache<NSString, NSData>()
    private let lock = NSLock()
    private var memoryIndex: [String: Set<String>] = [:]
    private var generations: [String: Int] = [:]
    private var epoch = 0
    private var inflight: [String: Flight] = [:]

    public init(directory: URL, decoder: any ArtworkThumbDecoding = ImageIOArtworkDecoder()) {
        self.directory = directory
        self.decoder = decoder
        memory.totalCostLimit = 32 * 1024 * 1024
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func memoryData(for key: ArtworkThumbKey) -> Data? {
        memory.object(forKey: key.token as NSString) as Data?
    }

    public func diskURL(for key: ArtworkThumbKey) -> URL {
        directory
            .appendingPathComponent(ArtworkThumbnails.folderName(sourcePath: key.sourcePath), isDirectory: true)
            .appendingPathComponent("\(key.bucket)-\(key.fileSize)-\(key.modifiedMilliseconds).jpg")
    }

    public func thumbnailJPEG(sourcePath: String, bucket: Int) async -> Data? {
        guard let stamp = ArtworkThumbnails.stamp(atPath: sourcePath) else { return nil }
        let key = ArtworkThumbKey(
            sourcePath: sourcePath,
            bucket: bucket,
            fileSize: stamp.size,
            modifiedMilliseconds: stamp.modifiedMilliseconds
        )
        return await thumbnailJPEG(key: key)
    }

    public func thumbnailJPEG(key: ArtworkThumbKey) async -> Data? {
        if let cached = memoryData(for: key) { return cached }
        guard ArtworkThumbnails.stamp(atPath: key.sourcePath) == ArtworkFileStamp(
            size: key.fileSize,
            modifiedMilliseconds: key.modifiedMilliseconds
        ) else { return nil }

        let flight = join(key)
        defer { leave(token: key.token, flightID: flight.id) }
        return await withTaskCancellationHandler {
            await flight.task.value
        } onCancel: {
            self.cancelIfOnlyWaiter(token: key.token, flightID: flight.id)
        }
    }

    /// Drops every thumbnail for this source path. Does not touch the source file.
    public func invalidate(sourcePath: String) {
        let tokens: [String] = lock.locked {
            generations[sourcePath, default: 0] += 1
            return Array(memoryIndex.removeValue(forKey: sourcePath) ?? [])
        }
        for token in tokens {
            memory.removeObject(forKey: token as NSString)
        }
        let folder = directory.appendingPathComponent(
            ArtworkThumbnails.folderName(sourcePath: sourcePath),
            isDirectory: true
        )
        try? FileManager.default.removeItem(at: folder)
    }

    /// Wipes the thumbnail directory and the memory cache.
    public func invalidateAll() {
        let tokens: [String] = lock.locked {
            epoch += 1
            for path in generations.keys {
                generations[path, default: 0] += 1
            }
            let tokens = memoryIndex.values.flatMap { $0 }
            memoryIndex.removeAll()
            return tokens
        }
        for token in tokens {
            memory.removeObject(forKey: token as NSString)
        }
        memory.removeAllObjects()
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in items {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private struct Flight {
        var id: UUID
        var task: Task<Data?, Never>
        var waiters: Int
    }

    private func join(_ key: ArtworkThumbKey) -> Flight {
        lock.lock()
        defer { lock.unlock() }
        if var flight = inflight[key.token], !flight.task.isCancelled {
            flight.waiters += 1
            inflight[key.token] = flight
            return flight
        }
        let flight = Flight(id: UUID(), task: Task.detached { [self] in
            self.loadUncached(key)
        }, waiters: 1)
        inflight[key.token] = flight
        return flight
    }

    private func leave(token: String, flightID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard var flight = inflight[token], flight.id == flightID else { return }
        flight.waiters -= 1
        if flight.waiters <= 0 {
            inflight.removeValue(forKey: token)
        } else {
            inflight[token] = flight
        }
    }

    private func cancelIfOnlyWaiter(token: String, flightID: UUID) {
        lock.lock()
        let flight = inflight[token]
        if let flight, flight.id == flightID, flight.waiters <= 1 {
            flight.task.cancel()
        }
        lock.unlock()
    }

    private func generation(of path: String) -> (epoch: Int, path: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (epoch, generations[path, default: 0])
    }

    private func loadUncached(_ key: ArtworkThumbKey) -> Data? {
        if Task.isCancelled { return nil }
        let seen = generation(of: key.sourcePath)
        if let cached = memoryData(for: key) { return cached }
        let file = diskURL(for: key)
        if let stored = try? Data(contentsOf: file), !stored.isEmpty, generation(of: key.sourcePath) == seen {
            storeMemory(stored, key: key)
            return stored
        }
        guard !Task.isCancelled, generation(of: key.sourcePath) == seen else { return nil }
        guard currentStampMatches(key) else { return nil }
        let source = URL(fileURLWithPath: key.sourcePath)
        guard let data = decoder.makeThumbnailJPEG(sourceURL: source, maxPixelSize: key.bucket),
              !data.isEmpty
        else { return nil }
        guard !Task.isCancelled, generation(of: key.sourcePath) == seen, currentStampMatches(key) else {
            return nil
        }
        writeDisk(data, key: key)
        storeMemory(data, key: key)
        return data
    }

    private func currentStampMatches(_ key: ArtworkThumbKey) -> Bool {
        ArtworkThumbnails.stamp(atPath: key.sourcePath) == ArtworkFileStamp(
            size: key.fileSize,
            modifiedMilliseconds: key.modifiedMilliseconds
        )
    }

    private func storeMemory(_ data: Data, key: ArtworkThumbKey) {
        memory.setObject(data as NSData, forKey: key.token as NSString, cost: data.count)
        lock.lock()
        memoryIndex[key.sourcePath, default: []].insert(key.token)
        lock.unlock()
    }

    private func writeDisk(_ data: Data, key: ArtworkThumbKey) {
        let url = diskURL(for: key)
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let partial = url.appendingPathExtension("partial")
        do {
            try data.write(to: partial, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: partial, to: url)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            return
        }
        if let siblings = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            let prefix = "\(key.bucket)-"
            for sibling in siblings where sibling.lastPathComponent.hasPrefix(prefix) && sibling.lastPathComponent != url.lastPathComponent {
                try? FileManager.default.removeItem(at: sibling)
            }
        }
    }
}

#if canImport(ImageIO)
enum ImageIOThumbnail {
    static func jpeg(sourceURL: URL, maxPixelSize: Int, quality: Double) -> Data? {
        guard maxPixelSize > 0 else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, sourceOptions) else { return nil }
        var limit = maxPixelSize
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
            let longest = max(width, height)
            if longest > 0 {
                limit = min(limit, longest)
            }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let encoded = NSMutableData()
        #if canImport(UniformTypeIdentifiers)
        let type = UTType.jpeg.identifier as CFString
        #else
        let type = "public.jpeg" as CFString
        #endif
        guard let destination = CGImageDestinationCreateWithData(encoded, type, 1, nil) else { return nil }
        let imageProperties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, imageProperties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return encoded as Data
    }
}
#endif

private extension NSLock {
    func locked<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
