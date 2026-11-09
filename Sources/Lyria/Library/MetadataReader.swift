import AVFoundation
import Foundation
import LyriaCore

struct ReadMetadata {
    var title: String
    var artist: String
    var album: String
    var year: Int
    var durationMs: Int
    var artwork: Data?
}

enum MetadataReader {
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "aiff", "aif", "wav", "flac"]

    /// Nil when AVFoundation cannot play the file. Tags fall back to empty strings.
    static func read(url: URL) async -> ReadMetadata? {
        let asset = AVURLAsset(url: url)
        do {
            guard try await asset.load(.isPlayable) else { return nil }
            let duration = try await asset.load(.duration)
            let metadata = (try? await asset.load(.metadata)) ?? []
            return ReadMetadata(
                title: await text(in: metadata, identifiers: [.commonIdentifierTitle]) ?? "",
                artist: await text(in: metadata, identifiers: [.commonIdentifierArtist]) ?? "",
                album: await text(in: metadata, identifiers: [.commonIdentifierAlbumName]) ?? "",
                year: await year(in: metadata),
                durationMs: milliseconds(duration),
                artwork: await artworkData(in: metadata)
            )
        } catch {
            return nil
        }
    }

    static func folderArtwork(near file: URL) -> Data? {
        let directory = file.deletingLastPathComponent()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return nil }
        let wanted: Set<String> = ["folder.jpg", "cover.jpg", "folder.jpeg", "cover.jpeg"]
        guard let match = names.first(where: { wanted.contains($0.lowercased()) }) else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(match))
    }

    private static func text(in items: [AVMetadataItem], identifiers: [AVMetadataIdentifier]) async -> String? {
        for identifier in identifiers {
            let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
            guard let value = try? await matches.first?.load(.stringValue) else { continue }
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private static func year(in items: [AVMetadataItem]) async -> Int {
        let preferred: [AVMetadataIdentifier] = [
            .commonIdentifierCreationDate,
        ]
        for identifier in preferred {
            let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
            if let value = try? await matches.first?.load(.stringValue), YearParser.parse(value) != 0 {
                return YearParser.parse(value)
            }
        }
        for item in items {
            let key = item.identifier?.rawValue.lowercased() ?? ""
            guard key.contains("year") || key.contains("tyer") || key.contains("date") || key.contains("day") else { continue }
            guard let value = try? await item.load(.stringValue) else { continue }
            let year = YearParser.parse(value)
            if year != 0 { return year }
        }
        return 0
    }

    private static func artworkData(in items: [AVMetadataItem]) async -> Data? {
        let keyed = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork)
        if let data = await firstData(in: keyed) { return data }
        var fallback: [AVMetadataItem] = []
        for item in items {
            let key = item.identifier?.rawValue.lowercased() ?? ""
            if key.contains("artwork") || key.contains("covr") || key.contains("apic") {
                fallback.append(item)
            }
        }
        return await firstData(in: fallback)
    }

    private static func firstData(in items: [AVMetadataItem]) async -> Data? {
        for item in items {
            if let data = try? await item.load(.dataValue), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    private static func milliseconds(_ time: CMTime) -> Int {
        guard time.isNumeric, time.seconds.isFinite, time.seconds > 0 else { return 0 }
        return Int((time.seconds * 1000).rounded())
    }
}
